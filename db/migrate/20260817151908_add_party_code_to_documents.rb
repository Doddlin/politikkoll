class AddPartyCodeToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :party_code, :string
    add_index :documents, :party_code
  end
end
