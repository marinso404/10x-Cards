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

ActiveRecord::Schema[8.1].define(version: 2026_03_06_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "flashcards", force: :cascade do |t|
    t.string "back", limit: 500, null: false
    t.datetime "created_at", null: false
    t.string "front", limit: 200, null: false
    t.bigint "generation_id"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["generation_id"], name: "index_flashcards_on_generation_id"
    t.index ["user_id"], name: "index_flashcards_on_user_id"
    t.check_constraint "char_length(back::text) > 0 AND char_length(back::text) <= 500", name: "chk_flashcards_back_length"
    t.check_constraint "char_length(front::text) > 0 AND char_length(front::text) <= 200", name: "chk_flashcards_front_length"
    t.check_constraint "source::text = ANY (ARRAY['manual'::character varying, 'ai_generated'::character varying, 'ai_edited'::character varying]::text[])", name: "chk_flashcards_source_value"
  end

  create_table "generation_error_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "error_code", null: false
    t.text "error_message", null: false
    t.bigint "generation_id", null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_id"], name: "index_generation_error_logs_on_generation_id"
  end

  create_table "generations", force: :cascade do |t|
    t.integer "accepted_edited_count", default: 0, null: false
    t.integer "accepted_unedited_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "generated_count", default: 0, null: false
    t.integer "generation_duration", null: false
    t.string "model", null: false
    t.text "source_text", null: false
    t.string "source_text_hash", null: false
    t.integer "source_text_length", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "source_text_hash"], name: "index_generations_on_user_id_and_source_text_hash", unique: true
    t.index ["user_id"], name: "index_generations_on_user_id"
    t.check_constraint "char_length(source_text) >= 1000 AND char_length(source_text) <= 10000", name: "chk_generations_source_text_length"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email_address", null: false
    t.string "first_name"
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  add_foreign_key "flashcards", "generations", on_delete: :nullify
  add_foreign_key "flashcards", "users", on_delete: :cascade
  add_foreign_key "generation_error_logs", "generations", on_delete: :cascade
  add_foreign_key "generations", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
end
