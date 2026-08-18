module Tools
  # Keyword search over imported document titles — the bridge from a topic
  # ("migration", "höjd skatt") to the beteckning that query_votes needs.
  # Plain ILIKE for now; swap for embeddings-based similarity once documents
  # have full text and the vector columns are actually populated.
  class DocumentSearch
    SCHEMA = {
      type: "function",
      function: {
        name: "search_documents",
        description: "Search imported Riksdagen documents (mainly betänkanden — " \
                      "committee reports) by keyword in their title, to find the " \
                      "beteckning relevant to a topic. Use this first when the user " \
                      "asks about a subject rather than naming an exact report.",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Swedish keyword or phrase, e.g. 'migration'" }
          },
          required: [ "query" ]
        }
      }
    }.freeze

    LIMIT = 8

    def self.call(query:)
      documents = Document.where("titel ILIKE ?", "%#{sanitize(query)}%").limit(LIMIT)

      if documents.none?
        return { found: false, message: "No imported documents match '#{query}'." }
      end

      {
        found: true,
        results: documents.map do |d|
          { dok_id: d.dok_id, rm: d.rm, doktyp: d.doktyp, beteckning: d.beteckning,
            organ: d.organ, titel: d.titel, source_url: d.source_url }
        end
      }
    end

    def self.sanitize(query)
      query.to_s.gsub(/[%_]/) { |m| "\\#{m}" }
    end
    private_class_method :sanitize
  end
end
