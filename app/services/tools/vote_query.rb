module Tools
  # The one tool the chat model can call in this first slice: look up how
  # each party voted on a specific committee report. Answers come only from
  # what's actually in the database — if nothing's been imported for the
  # requested report, that's what gets reported back, not a guess.
  class VoteQuery
    SCHEMA = {
      type: "function",
      function: {
        name: "query_votes",
        description: "Look up how each party voted on a specific committee report " \
                      "(beteckning) in a given riksmöte, with the per-party vote " \
                      "breakdown and a source reference for each vote.",
        parameters: {
          type: "object",
          properties: {
            rm: { type: "string", description: "riksmöte, e.g. 2023/24" },
            beteckning: { type: "string", description: "committee report code, e.g. FiU1" }
          },
          required: [ "rm", "beteckning" ]
        }
      }
    }.freeze

    def self.call(rm:, beteckning:)
      votes = Vote.where(rm: rm, beteckning: beteckning).order(:punkt)

      if votes.none?
        return { found: false, message: "No imported voting data for #{beteckning} #{rm} yet." }
      end

      {
        found: true,
        rm: rm,
        beteckning: beteckning,
        votes: votes.map { |vote| vote_payload(vote) }
      }
    end

    def self.vote_payload(vote)
      tally = Hash.new { |h, k| h[k] = Hash.new(0) }
      vote.party_tally.each { |(party, ballot), count| tally[party][ballot] = count }

      {
        punkt: vote.punkt,
        votering_id: vote.votering_id,
        source_url: "https://data.riksdagen.se/votering/#{vote.votering_id}",
        party_tally: tally
      }
    end
    private_class_method :vote_payload
  end
end
