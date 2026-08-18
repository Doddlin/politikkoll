module Tools
  # Semantic search over party election manifestos (valmanifest) — the
  # source for "what does this party say it wants to do", as opposed to
  # search_by_topic's "what has this party actually voted for/proposed."
  # Both matter and answer different questions; the model is told to use
  # whichever (or both) fit what was actually asked.
  class ManifestoSearch
    SCHEMA = {
      type: "function",
      function: {
        name: "search_manifesto",
        description: "Semantic search over party election manifestos (valmanifest) — " \
                      "what a party says it wants to do, as opposed to what it has " \
                      "historically voted for. Optionally filter to one party and/or " \
                      "election year.",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Swedish topic description, e.g. 'sänkt skatt'" },
            party: { type: "string", description: "optional party code filter: S, M, SD, C, V, KD, L, or MP" },
            election_year: { type: "integer", description: "optional election year filter, e.g. 2022" }
          },
          required: [ "query" ]
        }
      }
    }.freeze

    LIMIT = 6

    def self.call(query:, party: nil, election_year: nil, client: Mistral::Client.new)
      vector = client.embed(query).first

      scope = ManifestoChunk.where.not(embedding: nil)
      scope = scope.joins(:party).where(parties: { code: party }) if party.present?
      scope = scope.where(election_year: election_year) if election_year.present?

      results = scope.nearest_neighbors(:embedding, vector, distance: "cosine").first(LIMIT)

      if results.empty?
        return { found: false, message: "No imported manifesto content matches '#{query}'#{" for party #{party}" if party.present?}." }
      end

      {
        found: true,
        results: results.map do |c|
          { party: c.party.code, election_year: c.election_year, excerpt: c.content.truncate(600), source_url: c.source_url }
        end
      }
    end
  end
end
