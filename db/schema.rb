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

ActiveRecord::Schema[7.0].define(version: 2025_07_10_123341) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "custom_fields", force: :cascade do |t|
    t.string "name", null: false
    t.string "field_type", null: false
    t.text "description"
    t.boolean "required", default: false
    t.string "entity_type", default: "task"
    t.json "options", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "name"], name: "index_custom_fields_on_entity_type_and_name", unique: true
    t.index ["field_type"], name: "index_custom_fields_on_field_type"
  end

  create_table "events", force: :cascade do |t|
    t.text "description"
    t.datetime "date"
    t.bigint "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "responsible"
    t.index ["project_id"], name: "index_events_on_project_id"
  end

  create_table "image_projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "image_project_id", null: false
    t.index ["image_project_id"], name: "index_images_on_image_project_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "progress_updates", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.decimal "old_progress", precision: 5, scale: 2, null: false
    t.decimal "new_progress", precision: 5, scale: 2, null: false
    t.text "notes"
    t.string "update_type", default: "manual"
    t.bigint "updated_by_id"
    t.decimal "timeline_progress_at_update", precision: 5, scale: 2
    t.decimal "variance_at_update", precision: 5, scale: 2
    t.string "project_status_at_update"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_progress_updates_on_project_and_date"
    t.index ["project_id"], name: "index_progress_updates_on_project_id"
    t.index ["update_type"], name: "index_progress_updates_on_update_type"
    t.index ["updated_by_id", "created_at"], name: "index_progress_updates_on_user_and_date"
    t.index ["updated_by_id"], name: "index_progress_updates_on_updated_by_id"
    t.check_constraint "new_progress >= 0::numeric AND new_progress <= 100::numeric", name: "new_progress_range"
    t.check_constraint "old_progress >= 0::numeric AND old_progress <= 100::numeric", name: "old_progress_range"
  end

  create_table "project_managers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "project_milestones", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.text "description"
    t.date "planned_date"
    t.date "actual_date"
    t.decimal "progress_percentage_target", precision: 5, scale: 2, default: "0.0"
    t.integer "status", default: 0
    t.integer "order_position", default: 0
    t.bigint "assigned_to_id"
    t.bigint "depends_on_milestone_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actual_date"], name: "index_project_milestones_on_actual_date"
    t.index ["assigned_to_id"], name: "index_project_milestones_on_assigned_to_id"
    t.index ["depends_on_milestone_id"], name: "index_project_milestones_on_depends_on_milestone_id"
    t.index ["planned_date"], name: "index_project_milestones_on_planned_date"
    t.index ["project_id", "order_position"], name: "index_milestones_on_project_and_order"
    t.index ["project_id", "status"], name: "index_milestones_on_project_and_status"
    t.index ["project_id"], name: "index_project_milestones_on_project_id"
    t.check_constraint "progress_percentage_target >= 0::numeric AND progress_percentage_target <= 100::numeric", name: "milestone_progress_range"
  end

  create_table "projects", force: :cascade do |t|
    t.string "title"
    t.integer "status"
    t.bigint "project_manager_id", null: false
    t.bigint "supervisor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "location"
    t.date "finishing_date"
    t.string "lead_person"
    t.string "responsible"
    t.bigint "site_manager_id"
    t.decimal "progress_percentage", precision: 5, scale: 2, default: "0.0", null: false
    t.date "start_date"
    t.decimal "budget", precision: 15, scale: 2
    t.text "description"
    t.integer "priority", default: 1, null: false
    t.date "actual_start_date"
    t.date "estimated_completion_date"
    t.datetime "last_progress_update"
    t.text "progress_notes"
    t.index ["actual_start_date"], name: "index_projects_on_actual_start_date"
    t.index ["created_at"], name: "index_projects_on_created_at"
    t.index ["finishing_date"], name: "index_projects_on_finishing_date"
    t.index ["last_progress_update"], name: "index_projects_on_last_progress_update"
    t.index ["priority"], name: "index_projects_on_priority"
    t.index ["progress_percentage"], name: "index_projects_on_progress_percentage"
    t.index ["project_manager_id", "status"], name: "index_projects_on_manager_and_status"
    t.index ["project_manager_id"], name: "index_projects_on_project_manager_id"
    t.index ["site_manager_id"], name: "index_projects_on_site_manager_id"
    t.index ["start_date"], name: "index_projects_on_start_date"
    t.index ["status", "priority"], name: "index_projects_on_status_and_priority"
    t.index ["status"], name: "index_projects_on_status"
    t.index ["supervisor_id", "status"], name: "index_projects_on_supervisor_and_status"
    t.index ["supervisor_id"], name: "index_projects_on_supervisor_id"
    t.index ["updated_at"], name: "index_projects_on_updated_at"
    t.check_constraint "progress_percentage >= 0::numeric AND progress_percentage <= 100::numeric", name: "progress_percentage_range"
  end

  create_table "site_managers", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "location"
    t.string "specialization"
    t.integer "experience_years", default: 0
    t.integer "status", default: 0
    t.integer "availability", default: 0
    t.text "certifications"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_site_managers_on_email", unique: true
  end

  create_table "supervisors", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_supervisors_on_email", unique: true
  end

  create_table "task_assignees", id: false, force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.index ["task_id"], name: "index_task_assignees_on_task_id"
    t.index ["user_id"], name: "index_task_assignees_on_user_id"
  end

  create_table "task_watchers", id: false, force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.index ["task_id"], name: "index_task_watchers_on_task_id"
    t.index ["user_id"], name: "index_task_watchers_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "due_date"
    t.integer "status"
    t.bigint "project_manager_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.string "priority", default: "medium"
    t.decimal "estimated_hours", precision: 8, scale: 2
    t.bigint "project_id"
    t.json "custom_fields", default: {}
    t.json "tags", default: []
    t.boolean "is_starred", default: false
    t.boolean "is_archived", default: false
    t.bigint "user_id"
    t.string "status_string", default: "pending"
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["project_manager_id", "status"], name: "index_tasks_on_project_manager_id_and_status"
    t.index ["project_manager_id"], name: "index_tasks_on_project_manager_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "tenders", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.date "deadline"
    t.string "lead_person"
    t.string "responsible"
    t.bigint "project_manager_id"
    t.bigint "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "other_column_name"
    t.string "status", default: "draft"
    t.string "priority", default: "medium"
    t.string "category"
    t.string "location"
    t.string "client"
    t.decimal "budget_estimate", precision: 12, scale: 2
    t.string "estimated_duration"
    t.text "requirements"
    t.integer "submission_count", default: 0
    t.index ["deadline"], name: "index_tenders_on_deadline"
    t.index ["priority"], name: "index_tenders_on_priority"
    t.index ["project_id"], name: "index_tenders_on_project_id"
    t.index ["project_manager_id"], name: "index_tenders_on_project_manager_id"
    t.index ["status"], name: "index_tenders_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "name"
    t.string "nickname"
    t.string "image"
    t.string "email"
    t.text "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role"
    t.string "otp_secret"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login"
    t.boolean "admin", default: false, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "events", "projects"
  add_foreign_key "images", "image_projects"
  add_foreign_key "progress_updates", "projects"
  add_foreign_key "progress_updates", "users", column: "updated_by_id"
  add_foreign_key "project_milestones", "project_milestones", column: "depends_on_milestone_id"
  add_foreign_key "project_milestones", "projects"
  add_foreign_key "project_milestones", "users", column: "assigned_to_id"
  add_foreign_key "projects", "site_managers"
  add_foreign_key "projects", "users", column: "project_manager_id"
  add_foreign_key "projects", "users", column: "supervisor_id"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks", "users", column: "project_manager_id"
  add_foreign_key "tenders", "projects"
  add_foreign_key "tenders", "users", column: "project_manager_id"
end
