class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string   :event_type,  null: false
      t.string   :status,      null: false, default: "pending"
      t.string   :device_id
      t.jsonb    :payload,     null: false, default: {}
      t.datetime :received_at, null: false
      t.datetime :occurred_at
      t.datetime :processed_at
      t.text     :error_message

      t.timestamps
    end

    add_index :events, :event_type
    add_index :events, [ :event_type, :status ]
    add_index :events, :received_at
  end
end
