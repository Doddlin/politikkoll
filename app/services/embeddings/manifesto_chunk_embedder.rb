module Embeddings
  class ManifestoChunkEmbedder
    BATCH_SIZE = 20

    def self.call(...)
      new(...).call
    end

    def initialize(chunks, client: Mistral::Client.new)
      @chunks = Array(chunks)
      @client = client
    end

    def call
      count = 0

      @chunks.each_slice(BATCH_SIZE) do |batch|
        vectors = @client.embed(batch.map(&:content))

        batch.zip(vectors).each do |chunk, vector|
          chunk.update!(embedding: vector)
          count += 1
        end
      end

      count
    end
  end
end
