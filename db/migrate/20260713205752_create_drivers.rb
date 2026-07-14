class CreateDrivers < ActiveRecord::Migration[8.0]
  def change
    create_table :drivers do |t|
      t.string :name, null: false
      t.string :cpf, null: false
      t.string :phone, null: false
      t.string :notification_channel, null: false, default: "sms"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :drivers, :cpf, unique: true
  end
end
