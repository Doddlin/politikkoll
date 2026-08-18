module Tools
  # Vector similarity search over embedded motion/betänkande full text — the
  # tool for topic and stance questions ("how does S feel about tax cuts")
  # where the exact report title won't contain the user's wording. Only
  # searches documents that have actually been enriched with an embedding;
  # most haven't been yet, so this will often find nothing outside whatever
  # slice has been enriched so far.
  class SemanticSearch
    SCHEMA = {
      type: "function",
      function: {
        name: "search_by_topic",
        description: "Semantic search over motion and betänkande full text for a topic or " \
                      "stance question (e.g. 'skattesänkningar', 'vad har S föreslagit om välfärd'). " \
                      "Optionally filter to one party's own motions. Prefer this over " \
                      "search_documents whenever the question is about a subject or a party's " \
                      "position rather than a specific, already-known report.",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Swedish topic description, e.g. 'sänkt inkomstskatt'" },
            party: { type: "string", description: "optional party code filter: S, M, SD, C, V, KD, L, or MP" }
          },
          required: [ "query" ]
        }
      }
    }.freeze

    LIMIT = 6

    def self.call(query:, party: nil, client: Mistral::Client.new)
      vector = client.embed(query).first

      scope = Document.where.not(embedding: nil)
      scope = scope.where(party_code: party) if party.present?
      results = scope.nearest_neighbors(:embedding, vector, distance: "cosine").first(LIMIT)

      if results.empty?
        return { found: false, message: "No embedded documents match '#{query}'#{" for party #{party}" if party.present?}." }
      end

      {
        found: true,
        results: results.map { |d| document_payload(d) }
      }
    end

    def self.document_payload(document)
      {
        dok_id: document.dok_id, rm: document.rm, doktyp: document.doktyp,
        beteckning: document.beteckning, party: document.party_code, organ: document.organ,
        titel: document.titel, excerpt: document.full_text.to_s.truncate(500),
        source_url: document.source_url
      }
    end
    private_class_method :document_payload
  end
end
