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

ActiveRecord::Schema[7.1].define(version: 2025_09_01_203744) do
  create_table "app_daily_logs", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "app_user_id", null: false
    t.date "fecha", null: false
    t.datetime "morning_at"
    t.datetime "evening_at"
    t.boolean "morning_done", default: false, null: false
    t.boolean "evening_done", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "fecha"], name: "index_app_daily_logs_on_app_user_id_and_fecha", unique: true
    t.index ["app_user_id"], name: "index_app_daily_logs_on_app_user_id"
  end

  create_table "app_pause_windows", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "moment", null: false
    t.integer "hour", default: 11, null: false
    t.integer "minute", default: 0, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["moment"], name: "index_app_pause_windows_on_moment", unique: true
  end

  create_table "app_reminders", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "app_user_id", null: false
    t.date "fecha"
    t.string "moment"
    t.datetime "sent_at"
    t.datetime "opened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_user_id", "fecha", "moment"], name: "index_app_reminders_on_app_user_id_and_fecha_and_moment", unique: true
    t.index ["app_user_id"], name: "index_app_reminders_on_app_user_id"
  end

  create_table "app_users", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "rut", null: false
    t.string "correo", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "activo", default: true, null: false
    t.boolean "estado", default: false, null: false
    t.boolean "creado", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "expo_push_token"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.index ["confirmation_token"], name: "index_app_users_on_confirmation_token", unique: true
    t.index ["expo_push_token"], name: "index_app_users_on_expo_push_token"
    t.index ["rut"], name: "index_app_users_on_rut", unique: true
  end

  create_table "ivas", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "year"
    t.integer "month"
    t.decimal "valor", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "month"], name: "index_ivas_on_year_and_month", unique: true
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false
    t.datetime "deleted_at"
    t.boolean "super", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "app_daily_logs", "app_users"
  add_foreign_key "app_reminders", "app_users"
end
