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

ActiveRecord::Schema[7.1].define(version: 2026_03_17_191432) do
  create_table "app_banners", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "kind", null: false
    t.text "message", null: false
    t.string "link_url"
    t.string "link_label"
    t.boolean "enabled", default: true, null: false
    t.boolean "admin_only", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["admin_only"], name: "index_app_banners_on_admin_only"
    t.index ["enabled"], name: "index_app_banners_on_enabled"
    t.index ["kind"], name: "index_app_banners_on_kind"
  end

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
    t.string "password_digest"
    t.index ["confirmation_token"], name: "index_app_users_on_confirmation_token", unique: true
    t.index ["expo_push_token"], name: "index_app_users_on_expo_push_token"
    t.index ["password_digest"], name: "index_app_users_on_password_digest"
    t.index ["rut"], name: "index_app_users_on_rut", unique: true
  end

  create_table "check_checkeo_usuarios", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "check_usuario_id", null: false
    t.bigint "check_checkeo_id", null: false
    t.integer "estado_eliminacion", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_checkeo_id"], name: "index_check_checkeo_usuarios_on_check_checkeo_id"
    t.index ["check_usuario_id"], name: "index_check_checkeo_usuarios_on_check_usuario_id"
  end

  create_table "check_checkeos", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "check_patente_id", null: false
    t.date "fecha_chequeo", null: false
    t.boolean "completado", default: false, null: false
    t.boolean "corregido_fuera_de_fecha", default: false, null: false
    t.integer "extintor", default: 0, null: false
    t.integer "kit_derrame", default: 0, null: false
    t.boolean "botiquin", default: false, null: false
    t.boolean "gata", default: false, null: false
    t.boolean "cadenas", default: false, null: false
    t.boolean "llave_rueda", default: false, null: false
    t.boolean "antena_radio", default: false, null: false
    t.boolean "permiso_circulacion", default: false, null: false
    t.boolean "revision_tecnica", default: false, null: false
    t.boolean "soap", default: false, null: false
    t.boolean "alcohol", default: false, null: false
    t.boolean "protector_solar", default: false, null: false
    t.boolean "carpeta", default: false, null: false
    t.boolean "panos_limpieza", default: false, null: false
    t.boolean "conos", default: false, null: false
    t.boolean "radio_comunicacion", default: false, null: false
    t.boolean "espejo_inspeccion", default: false, null: false
    t.boolean "toldo", default: false, null: false
    t.boolean "pie_de_metro", default: false, null: false
    t.boolean "tintas", default: false, null: false
    t.boolean "arnes", default: false, null: false
    t.integer "falta_diclofenaco_cant", default: 0, null: false
    t.integer "falta_guantes_cant", default: 0, null: false
    t.integer "falta_parche_curita_cant", default: 0, null: false
    t.integer "falta_gasa_cant", default: 0, null: false
    t.integer "falta_venda_cant", default: 0, null: false
    t.integer "falta_suero_cant", default: 0, null: false
    t.integer "falta_tela_adhesiva_cant", default: 0, null: false
    t.integer "falta_palitos_cant", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_patente_id"], name: "index_check_checkeos_on_check_patente_id"
  end

  create_table "check_logs_ocultos", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "usuario_id_accion", null: false
    t.string "usuario_nombre", null: false
    t.string "accion_realizada", null: false
    t.string "patente_afectada", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "check_notificaciones", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "check_usuario_id", null: false
    t.integer "tipo_notificacion", default: 0, null: false
    t.boolean "leida", default: false, null: false
    t.text "mensaje"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_usuario_id"], name: "index_check_notificaciones_on_check_usuario_id"
  end

  create_table "check_patentes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "codigo", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo"], name: "index_check_patentes_on_codigo", unique: true
  end

  create_table "check_usuarios", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "rut", null: false
    t.string "nombre", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "push_token"
    t.index ["rut"], name: "index_check_usuarios_on_rut", unique: true
  end

  create_table "ivas", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "year"
    t.integer "month"
    t.decimal "valor", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "month"], name: "index_ivas_on_year_and_month", unique: true
  end

  create_table "mobility_adjustments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "empresa"
    t.string "mandante_rut"
    t.string "mandante_nombre"
    t.decimal "uf", precision: 10, scale: 4
    t.integer "servicios"
    t.date "fecha"
    t.string "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pausa_app_holidays", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.date "fecha", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fecha"], name: "index_pausa_app_holidays_on_fecha", unique: true
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
