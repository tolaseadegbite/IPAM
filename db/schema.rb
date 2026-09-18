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

ActiveRecord::Schema[8.1].define(version: 2026_09_18_204517) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "prefix", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id", "user_id"], name: "index_assignments_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_assignments_on_card_id"
    t.index ["user_id"], name: "index_assignments_on_user_id"
  end

  create_table "boards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "branches", force: :cascade do |t|
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_branches_on_name", unique: true
  end

  create_table "card_activities", force: :cascade do |t|
    t.integer "action", default: 0, null: false
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_card_activities_on_action"
    t.index ["card_id", "created_at"], name: "index_card_activities_on_card_id_and_created_at"
    t.index ["card_id"], name: "index_card_activities_on_card_id"
    t.index ["user_id"], name: "index_card_activities_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "list_id", null: false
    t.text "notes"
    t.integer "position", null: false
    t.integer "priority", default: 0, null: false
    t.bigint "referenceable_id"
    t.string "referenceable_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id", "position"], name: "index_cards_on_list_id_and_position"
    t.index ["list_id"], name: "index_cards_on_list_id"
    t.index ["referenceable_type", "referenceable_id"], name: "index_cards_on_referenceable"
  end

  create_table "chats", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "mode", default: "plan", null: false
    t.bigint "ruby_llm_model_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.integer "devices_count", default: 0, null: false
    t.integer "employees_count", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_departments_on_branch_id"
    t.index ["name", "branch_id"], name: "index_departments_on_name_and_branch_id", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "critical", default: false
    t.bigint "department_id", null: false
    t.integer "device_type", default: 0, null: false
    t.bigint "employee_id"
    t.string "location"
    t.string "mac_address"
    t.string "name", null: false
    t.text "notes"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["critical"], name: "index_devices_on_critical"
    t.index ["department_id"], name: "index_devices_on_department_id"
    t.index ["device_type"], name: "index_devices_on_device_type"
    t.index ["employee_id"], name: "index_devices_on_employee_id"
    t.index ["mac_address"], name: "index_devices_on_mac_address", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
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
    t.datetime "last_seen_at"
    t.text "notes"
    t.integer "reachability_status", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "subnet_id", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_ip_addresses_on_address", unique: true
    t.index ["device_id"], name: "index_ip_addresses_on_device_id"
    t.index ["last_seen_at"], name: "index_ip_addresses_on_last_seen_at"
    t.index ["reachability_status"], name: "index_ip_addresses_on_reachability_status"
    t.index ["status"], name: "index_ip_addresses_on_status"
    t.index ["subnet_id"], name: "index_ip_addresses_on_subnet_id"
  end

  create_table "lists", force: :cascade do |t|
    t.bigint "board_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id", "position"], name: "index_lists_on_board_id_and_position"
    t.index ["board_id"], name: "index_lists_on_board_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.boolean "cache_until_here", default: false, null: false
    t.integer "cached_tokens"
    t.bigint "chat_id", null: false
    t.jsonb "citations"
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.string "finish_reason"
    t.integer "input_tokens"
    t.bigint "model_id"
    t.integer "output_tokens"
    t.jsonb "raw_content"
    t.jsonb "raw_reasoning"
    t.string "role", null: false
    t.jsonb "server_tool_calls"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "network_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "device_id"
    t.inet "ip_address"
    t.integer "kind", default: 0
    t.string "message", null: false
    t.index ["created_at", "kind"], name: "index_network_events_on_created_at_and_kind"
    t.index ["device_id"], name: "index_network_events_on_device_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "batch_protocol"
    t.jsonb "chat_ids", default: []
    t.string "chat_type"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "provider_batch_id", null: false
    t.string "raw_status"
    t.jsonb "reported_cost"
    t.jsonb "request_counts"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "unlisted_at"
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ruby_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["modalities"], name: "index_ruby_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "approval"
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "message_type", null: false
    t.string "name", null: false
    t.boolean "remote", default: false, null: false
    t.bigint "result_id"
    t.string "result_type"
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.integer "cache_read_tokens"
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.integer "cache_write_tokens"
    t.bigint "chat_id", null: false
    t.string "chat_type", null: false
    t.datetime "created_at", null: false
    t.decimal "input_cost", precision: 16, scale: 10
    t.integer "input_tokens"
    t.bigint "message_id"
    t.string "message_type"
    t.string "model", null: false
    t.string "operation", null: false
    t.decimal "output_cost", precision: 16, scale: 10
    t.integer "output_tokens"
    t.string "provider", null: false
    t.string "status", null: false
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.integer "thinking_tokens"
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation::text = ANY (ARRAY['chat'::character varying, 'embedding'::character varying, 'moderation'::character varying, 'image'::character varying, 'speech'::character varying, 'transcription'::character varying, 'ocr'::character varying, 'rerank'::character varying]::text[])"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'succeeded'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])"
  end

  create_table "ruby_llm_v2_backfills", id: false, force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.bigint "last_id"
    t.string "task", null: false
    t.index ["task"], name: "index_ruby_llm_v2_backfills_on_task", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subnets", force: :cascade do |t|
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.inet "gateway"
    t.integer "ip_addresses_count", default: 0, null: false
    t.string "name", null: false
    t.cidr "network_address", null: false
    t.datetime "updated_at", null: false
    t.integer "vlan_id"
    t.index ["branch_id"], name: "index_subnets_on_branch_id"
    t.index ["network_address"], name: "index_subnets_on_network_address", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "assignments", "cards"
  add_foreign_key "assignments", "users"
  add_foreign_key "card_activities", "cards"
  add_foreign_key "card_activities", "users"
  add_foreign_key "cards", "lists"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "chats", "users"
  add_foreign_key "departments", "branches"
  add_foreign_key "devices", "departments"
  add_foreign_key "devices", "employees"
  add_foreign_key "employees", "departments"
  add_foreign_key "events", "users"
  add_foreign_key "ip_addresses", "devices"
  add_foreign_key "ip_addresses", "subnets"
  add_foreign_key "lists", "boards"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "ruby_llm_models", column: "model_id"
  add_foreign_key "messages", "ruby_llm_tool_calls", column: "tool_call_id"
  add_foreign_key "network_events", "devices"
  add_foreign_key "sessions", "users"
  add_foreign_key "subnets", "branches"
end
