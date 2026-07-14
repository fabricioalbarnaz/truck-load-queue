# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_14_132552) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "driver_trucks", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "truck_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["driver_id", "truck_id"], name: "index_driver_trucks_on_driver_id_and_truck_id", unique: true
    t.index ["driver_id"], name: "index_driver_trucks_on_driver_id"
    t.index ["truck_id"], name: "index_driver_trucks_on_truck_id"
  end

  create_table "drivers", force: :cascade do |t|
    t.string "name", null: false
    t.string "cpf", null: false
    t.string "phone", null: false
    t.string "notification_channel", default: "sms", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_drivers_on_cpf", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "trucks", force: :cascade do |t|
    t.string "plate", null: false
    t.string "model"
    t.integer "capacity"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plate"], name: "index_trucks_on_plate", unique: true
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "visits", force: :cascade do |t|
    t.bigint "driver_id", null: false
    t.bigint "truck_id", null: false
    t.string "status", default: "in_yard", null: false
    t.datetime "entered_yard_at", null: false
    t.datetime "order_issued_at"
    t.datetime "loading_started_at"
    t.datetime "finished_at"
    t.bigint "checked_in_by_id", null: false
    t.bigint "order_issued_by_id"
    t.bigint "finished_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_in_by_id"], name: "index_visits_on_checked_in_by_id"
    t.index ["driver_id", "status"], name: "index_visits_on_driver_id_and_status"
    t.index ["driver_id"], name: "index_visits_on_driver_id"
    t.index ["finished_by_id"], name: "index_visits_on_finished_by_id"
    t.index ["order_issued_at"], name: "index_visits_on_order_issued_at"
    t.index ["order_issued_by_id"], name: "index_visits_on_order_issued_by_id"
    t.index ["truck_id", "status"], name: "index_visits_on_truck_id_and_status"
    t.index ["truck_id"], name: "index_visits_on_truck_id"
  end

  add_foreign_key "driver_trucks", "drivers"
  add_foreign_key "driver_trucks", "trucks"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "visits", "drivers"
  add_foreign_key "visits", "trucks"
  add_foreign_key "visits", "users", column: "checked_in_by_id"
  add_foreign_key "visits", "users", column: "finished_by_id"
  add_foreign_key "visits", "users", column: "order_issued_by_id"
end
