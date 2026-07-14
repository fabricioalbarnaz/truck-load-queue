class CreateVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :visits do |t|
      t.references :driver, null: false, foreign_key: true
      t.references :truck, null: false, foreign_key: true
      t.string :status, null: false, default: "in_yard"
      t.datetime :entered_yard_at, null: false
      t.datetime :order_issued_at
      t.datetime :loading_started_at
      t.datetime :finished_at
      t.references :checked_in_by, null: false, foreign_key: { to_table: :users }
      t.references :order_issued_by, foreign_key: { to_table: :users }
      t.references :finished_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :visits, :order_issued_at
    add_index :visits, [ :driver_id, :status ]
    add_index :visits, [ :truck_id, :status ]
  end
end
