class CreateVoteRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :vote_records do |t|
      t.references :vote, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :party_code
      t.string :constituency
      t.integer :ballot

      t.timestamps
    end
    add_index :vote_records, [ :vote_id, :member_id ], unique: true
    add_index :vote_records, [ :party_code, :ballot ]
  end
end
