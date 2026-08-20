module Chat
  Answer = Data.define(:text, :sources, :vote_boards)

  # Orchestrates one turn of a conversation: sends the prior history plus the
  # new question to Mistral with the available tools, executes whatever the
  # model asks for against the real database — possibly across several
  # rounds (e.g. search_documents to find a beteckning, then query_votes on
  # it) — then persists the turn and returns a final, sourced answer.
  class Answerer
    SYSTEM_PROMPT = <<~PROMPT.squish
      You are politikkoll, a Swedish civic tool that helps people understand
      how political parties have actually voted in the Riksdag. You never
      recommend a party or tell someone how to vote — you only report what
      the data shows. Answer strictly from tool results, never from general
      knowledge or assumptions about Swedish politics. The choice between
      tools depends on whether you need the actual content of a document or
      just need to locate one: search_documents only returns titles and
      citations, nothing else, so use it purely to find a beteckning (e.g.
      before calling query_votes) when you don't need to say anything about
      what the document contains. Whenever you need to explain, summarize,
      or describe what a motion or betänkande actually says — including when
      the user already quotes or names its exact title — use search_by_topic
      instead; it's semantic search over full text (optionally filtered to
      one party's own motions) and returns real content, not just a title.
      When in doubt, prefer search_by_topic. Once you have a beteckning, use
      query_votes to get the actual vote breakdown on it. search_manifesto
      is a different kind of source: it's what a party currently says it
      wants to do (its election manifesto), not what it has historically
      voted for — use it for "what does X want" or "what is X's position"
      questions, and use search_by_topic/query_votes for "what has X
      actually done" questions. If someone asks about a party's stance
      broadly, consider using both and being clear about which is which:
      manifesto is the stated platform, voting record is the track record,
      and they don't always agree — that gap is often the most useful thing
      to surface, not something to paper over. query_statistics is a third,
      independent kind of source: real SCB (Statistics Sweden) government
      statistics, not controlled by any party. Use it whenever a claim you
      find (in a motion, manifesto, or debate) references a real-world trend
      — unemployment, inflation — so you can check what actually happened
      against what's claimed. Only the topics query_statistics reports as
      available exist; don't guess at others. None of your tools break votes
      down by valkrets (electoral district) — if someone asks how a
      specific district or region voted, or whether districts differ on a
      topic, say you can't compute that here and point them to the district
      map on the site instead of inferring an answer from party affiliation
      or general knowledge. And even where district data does exist (on
      that map), a district's aggregate Ja/Nej share on a topic mostly
      reflects which parties hold its seats, not a distinct regional
      opinion — don't state or imply that a district or region "supports"
      or "opposes" a topic, since Swedish MPs vote almost entirely along
      party lines. Every factual claim you make must be backed by a tool
      call from THIS turn, not memory of an earlier one — if a follow-up
      question revisits something already discussed (e.g. "and the
      Moderates?"), call the relevant tool again rather than restating it
      from the earlier reply, so a fresh, visible citation is always
      attached. It's fine to have no citation for a genuinely non-factual
      reply (a greeting, or clarifying what you can help with) — but never
      state or restate a specific fact, number, or vote result without one.
      The same applies to vote outcomes specifically: never describe how
      something was voted on — Ja, Nej, avstod, was passed, was rejected —
      in your own words without having called query_votes for it this
      turn; the app renders the real per-party breakdown as a visual
      component from that tool's result, and prose alone skips it. A
      frequent trap when interpreting query_votes results: a committee
      report (betänkande) often proposes to REJECT (avslå) the motion under
      discussion rather than approve it, so Ja in the roll call can mean
      voting for the rejection — i.e. against the motion's original ask —
      not for it. Never translate Ja/Nej into everyday language like
      "supports" or "opposes" a policy purely from the tally; first check,
      from the actual proposal text (search_by_topic or search_documents),
      whether that punkt's proposal is to approve or reject what's being
      asked, and say so explicitly (e.g. "utskottet föreslog avslag, så Ja
      betyder nej till...") rather than silently assuming the mapping. If
      you can't determine that with confidence, report the raw Ja/Nej/avstod
      breakdown per party without asserting which real-world position it
      corresponds to, rather than guessing and risking getting it backwards.
      If a tool reports
      no data, say plainly that you don't have that
      imported yet — don't guess or fall back on what you might otherwise
      know; only a small slice of documents have been enriched with full
      text and embeddings so far, so search_by_topic will often find
      nothing even on reasonable questions. When you do have data, mention
      which committee report or motion (beteckning and riksmöte), or which
      manifesto (party and election year), it's based on. This is an
      ongoing conversation — use the earlier turns for
      context (e.g. "and the Moderates?" refers back to whatever was just
      discussed) instead of asking the user to repeat themselves. Reply in
      the same language the user just wrote in — most questions will be in
      Swedish, but switch to English (or whatever language they used)
      without commentary if they ask in something else. The underlying
      source data (party names, committee names, document titles) is
      Swedish regardless of reply language — keep those in their original
      Swedish form rather than translating them, since that's what someone
      would need to find the actual source. Answer conversationally, in 2-4
      sentences. Plain text only, no markdown, no bold, no links, since
      sources are already shown separately as citations.
    PROMPT

    TOOLS = [
      Tools::VoteQuery::SCHEMA, Tools::DocumentSearch::SCHEMA, Tools::SemanticSearch::SCHEMA,
      Tools::ManifestoSearch::SCHEMA, Tools::StatisticsQuery::SCHEMA
    ].freeze
    MAX_ROUNDS = 5
    MAX_BOARDS_PER_ANSWER = 2

    def initialize(client: Mistral::Client.new)
      @client = client
    end

    def ask(conversation, question)
      history = conversation.chat_messages.map { |m| { role: m.role, content: m.content } }
      messages = [ { role: "system", content: SYSTEM_PROMPT }, *history, { role: "user", content: question } ]
      sources = []
      vote_boards = []
      answer = nil

      MAX_ROUNDS.times do
        response = @client.chat(messages: messages, model: "mistral-large-latest", tools: TOOLS, tool_choice: "auto")
        message = response.dig("choices", 0, "message")

        if message["tool_calls"].blank?
          answer = Answer.new(text: strip_markdown(extract_text(message["content"])), sources: sources.uniq, vote_boards: vote_boards.first(MAX_BOARDS_PER_ANSWER))
          break
        end

        messages << message

        message["tool_calls"].each do |tool_call|
          name = tool_call.dig("function", "name")
          result = execute_tool(name, tool_call)
          sources.concat(extract_sources(name, result))
          vote_boards.concat(build_vote_boards(result)) if name == "query_votes"

          messages << { role: "tool", tool_call_id: tool_call["id"], content: result.to_json }
        end
      end

      answer ||= Answer.new(text: "Kunde inte ta fram ett svar just nu — försök gärna igen.", sources: sources.uniq, vote_boards: vote_boards.first(MAX_BOARDS_PER_ANSWER))
      persist!(conversation, question, answer)
      answer
    end

    private

    # The model doesn't always follow the "no markdown" instruction — strip
    # the common cases rather than relying purely on prompt compliance.
    def strip_markdown(text)
      text.gsub(/\*\*(.+?)\*\*/, '\1').gsub(/\[(.+?)\]\(.+?\)/, '\1')
    end

    # message["content"] is normally a plain string, but was observed in
    # production coming back as an array of content parts instead (crashed
    # with NoMethodError on #gsub) — couldn't force a live reproduction to
    # confirm the exact part shape (hit Mistral's rate limit trying), so
    # this handles the general pattern other chat-completion APIs use for
    # multi-part content ([{"type" => "text", "text" => "..."}, ...]) and
    # falls back safely for anything else rather than risk crashing again.
    def extract_text(content)
      case content
      when String then content
      when Array
        content.filter_map { |part| part.is_a?(Hash) ? (part["text"] || part["content"]) : part.to_s.presence }.join
      when nil then ""
      else content.to_s
      end
    end

    def execute_tool(name, tool_call)
      args = JSON.parse(tool_call.dig("function", "arguments"), symbolize_names: true)

      case name
      when "query_votes" then Tools::VoteQuery.call(**args)
      when "search_documents" then Tools::DocumentSearch.call(**args)
      when "search_by_topic" then Tools::SemanticSearch.call(**args)
      when "search_manifesto" then Tools::ManifestoSearch.call(**args)
      when "query_statistics" then Tools::StatisticsQuery.call(**args)
      else { error: "unknown tool #{name}" }
      end
    end

    def extract_sources(name, result)
      case name
      when "query_votes"
        return [] unless result[:found]

        result[:votes].map do |v|
          { label: "#{result[:beteckning]} #{result[:rm]}, punkt #{v[:punkt]}", url: v[:source_url] }
        end
      when "search_documents", "search_by_topic"
        return [] unless result[:found]

        result[:results].map { |d| { label: "#{d[:beteckning]} — #{d[:titel]}", url: d[:source_url] } }
      when "search_manifesto"
        return [] unless result[:found]

        result[:results].map { |c| { label: "#{c[:party]} valmanifest #{c[:election_year]}", url: c[:source_url] } }
      when "query_statistics"
        return [] unless result[:found]

        [ { label: "SCB: #{result[:label]}", url: "https://www.scb.se" } ]
      else
        []
      end
    end

    # Turns a query_votes result into renderable vote-board data via
    # Vote#board (shared with the document detail page).
    def build_vote_boards(result)
      return [] unless result[:found]

      result[:votes].filter_map { |v| Vote.find_by(votering_id: v[:votering_id])&.board }
    end

    def persist!(conversation, question, answer)
      conversation.chat_messages.create!(role: "user", content: question)
      conversation.chat_messages.create!(
        role: "assistant", content: answer.text, sources: answer.sources, vote_boards: answer.vote_boards
      )
    end
  end
end
