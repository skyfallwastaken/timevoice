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

ActiveRecord::Schema[8.2].define(version: 2026_02_03_193421) do
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

  create_table "clients", force: :cascade do |t|
    t.text "billing_address"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_clients_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_clients_on_workspace_id"
  end

  create_table "invites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.integer "inviter_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "pending", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["email"], name: "index_invites_on_email"
    t.index ["inviter_id"], name: "index_invites_on_inviter_id"
    t.index ["token"], name: "index_invites_on_token", unique: true
    t.index ["workspace_id", "email"], name: "index_invites_on_workspace_id_and_email", unique: true, where: "status = 'pending'"
    t.index ["workspace_id"], name: "index_invites_on_workspace_id"
  end

  create_table "invoice_lines", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "invoice_id", null: false
    t.decimal "qty_hours", precision: 5, scale: 2
    t.integer "rate_cents"
    t.integer "time_entry_id"
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_lines_on_invoice_id"
    t.index ["time_entry_id"], name: "index_invoice_lines_on_time_entry_id"
  end

  create_table "invoice_settings", force: :cascade do |t|
    t.integer "billable_rate_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "sender_address"
    t.string "sender_name", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["workspace_id"], name: "index_invoice_settings_on_workspace_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.date "issued_on", null: false
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.string "status", default: "draft", null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["workspace_id", "client_id"], name: "index_invoices_on_workspace_id_and_client_id"
    t.index ["workspace_id"], name: "index_invoices_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.index ["role"], name: "index_memberships_on_role"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_memberships_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "projects", force: :cascade do |t|
    t.boolean "billable_default", default: false
    t.integer "client_id"
    t.string "color", default: "#b16286"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["color"], name: "index_projects_on_color"
    t.index ["workspace_id", "name"], name: "index_projects_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_projects_on_workspace_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_tags_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_tags_on_workspace_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.boolean "billable", default: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_seconds"
    t.datetime "end_at"
    t.integer "project_id"
    t.datetime "start_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.index ["billable"], name: "index_time_entries_on_billable"
    t.index ["project_id"], name: "index_time_entries_on_project_id"
    t.index ["start_at"], name: "index_time_entries_on_start_at"
    t.index ["user_id", "workspace_id"], name: "index_time_entries_on_user_id_and_workspace_id"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
    t.index ["workspace_id"], name: "index_time_entries_on_workspace_id"
  end

  create_table "time_entry_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "time_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_time_entry_tags_on_tag_id"
    t.index ["time_entry_id", "tag_id"], name: "index_time_entry_tags_on_time_entry_id_and_tag_id", unique: true
    t.index ["time_entry_id"], name: "index_time_entry_tags_on_time_entry_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "google_uid", null: false
    t.integer "last_used_workspace_id"
    t.string "name", null: false
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.index ["last_used_workspace_id"], name: "index_users_on_last_used_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_workspaces_on_name"
    t.index ["owner_id"], name: "index_workspaces_on_owner_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "clients", "workspaces"
  add_foreign_key "invites", "users", column: "inviter_id"
  add_foreign_key "invites", "workspaces"
  add_foreign_key "invoice_lines", "invoices"
  add_foreign_key "invoice_lines", "time_entries"
  add_foreign_key "invoice_settings", "workspaces"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "projects", "clients"
  add_foreign_key "projects", "workspaces"
  add_foreign_key "tags", "workspaces"
  add_foreign_key "time_entries", "projects"
  add_foreign_key "time_entries", "users"
  add_foreign_key "time_entries", "workspaces"
  add_foreign_key "time_entry_tags", "tags"
  add_foreign_key "time_entry_tags", "time_entries"
  add_foreign_key "users", "workspaces", column: "last_used_workspace_id"
  add_foreign_key "workspaces", "users", column: "owner_id"
end
