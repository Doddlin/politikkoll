class CreateParties < ActiveRecord::Migration[8.1]
  def change
    create_table :parties do |t|
      t.string :code
      t.string :name
      t.string :color

      t.timestamps
    end
    add_index :parties, :code, unique: true
  end
end
