class CreateManifestoChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :manifesto_chunks do |t|
      t.references :party, null: false, foreign_key: true
      t.integer :election_year
      t.string :section_title
      t.text :content
      t.string :source_url

      t.timestamps
    end
  end
end
