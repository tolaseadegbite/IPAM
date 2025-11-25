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

ActiveRecord::Schema[8.1].define(version: 2025_11_25_164824) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "branches", force: :cascade do |t|
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_branches_on_name", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_departments_on_branch_id"
    t.index ["name", "branch_id"], name: "index_departments_on_name_and_branch_id", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.string "asset_tag"
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.integer "device_type", default: 0, null: false
    t.bigint "employee_id"
    t.string "name", null: false
    t.text "notes"
    t.string "serial_number", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["asset_tag"], name: "index_devices_on_asset_tag", unique: true
    t.index ["department_id"], name: "index_devices_on_department_id"
    t.index ["device_type"], name: "index_devices_on_device_type"
    t.index ["employee_id"], name: "index_devices_on_employee_id"
    t.index ["serial_number"], name: "index_devices_on_serial_number", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone_number"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["phone_number"], name: "index_employees_on_phone_number", unique: true
    t.index ["status"], name: "index_employees_on_status"
  end

  create_table "events", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "ip_addresses", force: :cascade do |t|
    t.inet "address", null: false
    t.datetime "created_at", null: false
    t.bigint "device_id"
    t.text "notes"
    t.integer "status", default: 0, null: false
    t.bigint "subnet_id", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_ip_addresses_on_address", unique: true
    t.index ["device_id"], name: "index_ip_addresses_on_device_id"
    t.index ["subnet_id"], name: "index_ip_addresses_on_subnet_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "sudo_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subnets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.inet "gateway"
    t.string "name", null: false
    t.cidr "network_address", null: false
    t.datetime "updated_at", null: false
    t.integer "vlan_id"
    t.index ["network_address"], name: "index_subnets_on_network_address", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "departments", "branches"
  add_foreign_key "devices", "departments"
  add_foreign_key "devices", "employees"
  add_foreign_key "employees", "departments"
  add_foreign_key "events", "users"
  add_foreign_key "ip_addresses", "devices"
  add_foreign_key "ip_addresses", "subnets"
  add_foreign_key "sessions", "users"
end
