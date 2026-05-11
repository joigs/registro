class MergeCheckUsuarioIntoAppUser < ActiveRecord::Migration[7.1]
  def up
    add_column :app_users, :expo_push_token_camioneta, :string
    add_index :app_users, :expo_push_token_camioneta


    execute "DELETE FROM check_checkeo_usuarios"
    execute "DELETE FROM check_notificaciones"
    execute "DELETE FROM check_checkeos"
    execute "DELETE FROM check_patentes"

    remove_index :check_checkeo_usuarios, name: "index_check_checkeo_usuarios_on_check_usuario_id"
    rename_column :check_checkeo_usuarios, :check_usuario_id, :app_user_id
    add_index :check_checkeo_usuarios, :app_user_id, name: "index_check_checkeo_usuarios_on_app_user_id"

    remove_index :check_notificaciones, name: "index_check_notificaciones_on_check_usuario_id"
    rename_column :check_notificaciones, :check_usuario_id, :app_user_id
    add_index :check_notificaciones, :app_user_id, name: "index_check_notificaciones_on_app_user_id"

    drop_table :check_usuarios
  end

  def down
    create_table :check_usuarios, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.string :rut, null: false
      t.string :nombre, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.string :push_token
      t.index :rut, unique: true, name: "index_check_usuarios_on_rut"
    end

    remove_index :check_notificaciones, name: "index_check_notificaciones_on_app_user_id"
    rename_column :check_notificaciones, :app_user_id, :check_usuario_id
    add_index :check_notificaciones, :check_usuario_id, name: "index_check_notificaciones_on_check_usuario_id"

    remove_index :check_checkeo_usuarios, name: "index_check_checkeo_usuarios_on_app_user_id"
    rename_column :check_checkeo_usuarios, :app_user_id, :check_usuario_id
    add_index :check_checkeo_usuarios, :check_usuario_id, name: "index_check_checkeo_usuarios_on_check_usuario_id"

    remove_index :app_users, :expo_push_token_camioneta
    remove_column :app_users, :expo_push_token_camioneta
  end
end