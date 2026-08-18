class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :dok_id
      t.string :rm
      t.string :doktyp
      t.string :subtyp
      t.string :beteckning
      t.text :titel
      t.string :authors
      t.string :organ
      t.date :published_at
      t.text :full_text
      t.string :source_url

      t.timestamps
    end
    add_index :documents, :dok_id, unique: true
  end
end
