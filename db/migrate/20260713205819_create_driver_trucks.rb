class CreateDriverTrucks < ActiveRecord::Migration[8.0]
  def change
    create_table :driver_trucks do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :truck, null: false, foreign_key: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :driver_trucks, [ :driver_id, :truck_id ], unique: true
  end
end
