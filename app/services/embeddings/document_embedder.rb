module Embeddings
  # Embeds a document's title + full text via mistral-embed and stores the
  # vector on the existing (until now unused) documents.embedding column.
  # One embedding per document — fine for motions and most betänkanden,
  # which are short; long documents get truncated rather than chunked, a
  # simplification worth revisiting if it turns out to matter.
  class DocumentEmbedder
    MAX_CHARS = 6000 # rough, conservative proxy for the model's token limit
    BATCH_SIZE = 20

    def self.call(...)
      new(...).call
    end

    def initialize(documents, client: Mistral::Client.new)
      @documents = Array(documents)
      @client = client
    end

    def call
      count = 0

      @documents.each_slice(BATCH_SIZE) do |batch|
        texts = batch.map { |d| build_input(d) }
        vectors = @client.embed(texts)

        batch.zip(vectors).each do |document, vector|
          document.update!(embedding: vector)
          count += 1
        end
      end

      count
    end

    private

    def build_input(document)
      "#{document.titel}\n\n#{document.full_text}".truncate(MAX_CHARS, omission: "")
    end
  end
end
