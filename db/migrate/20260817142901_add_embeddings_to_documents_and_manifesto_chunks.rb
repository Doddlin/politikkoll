class AddEmbeddingsToDocumentsAndManifestoChunks < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :embedding, :vector, limit: 1024
    add_column :manifesto_chunks, :embedding, :vector, limit: 1024

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :manifesto_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
