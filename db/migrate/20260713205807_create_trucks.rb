class CreateTrucks < ActiveRecord::Migration[8.0]
  def change
    create_table :trucks do |t|
      t.string :plate, null: false
      t.string :model
      t.integer :capacity
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :trucks, :plate, unique: true
  end
end
