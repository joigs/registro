class CreateCheckTables < ActiveRecord::Migration[7.1]
  def change
    create_table "check_usuarios", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.string "rut", null: false
      t.string "nombre", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["rut"], name: "index_check_usuarios_on_rut", unique: true
    end

    create_table "check_patentes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.string "codigo", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["codigo"], name: "index_check_patentes_on_codigo", unique: true
    end

    create_table "check_checkeos", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
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

    create_table "check_checkeo_usuarios", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.bigint "check_usuario_id", null: false
      t.bigint "check_checkeo_id", null: false
      t.integer "estado_eliminacion", default: 0, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["check_checkeo_id"], name: "index_check_checkeo_usuarios_on_check_checkeo_id"
      t.index ["check_usuario_id"], name: "index_check_checkeo_usuarios_on_check_usuario_id"
    end

    create_table "check_notificaciones", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.bigint "check_usuario_id", null: false
      t.integer "tipo_notificacion", default: 0, null: false
      t.boolean "leida", default: false, null: false
      t.text "mensaje"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["check_usuario_id"], name: "index_check_notificaciones_on_check_usuario_id"
    end

    create_table "check_logs_ocultos", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
      t.integer "usuario_id_accion", null: false
      t.string "usuario_nombre", null: false
      t.string "accion_realizada", null: false
      t.string "patente_afectada", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
  end
end