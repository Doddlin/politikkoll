class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.string :votering_id
      t.string :rm
      t.string :beteckning
      t.integer :punkt
      t.string :dok_id
      t.string :avser
      t.date :voted_on

      t.timestamps
    end
    add_index :votes, :votering_id, unique: true
    add_index :votes, [ :rm, :beteckning, :punkt ]
  end
end
