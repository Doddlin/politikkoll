class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.string :intressent_id
      t.string :first_name
      t.string :last_name

      t.timestamps
    end
    add_index :members, :intressent_id, unique: true
  end
end
