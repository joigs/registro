class CreateFotosMelonSesiones < ActiveRecord::Migration[7.1]
  def change
    create_table :fotos_melon_sesiones do |t|
      t.string :token, null: false
      t.bigint :sec_user_id, null: false
      t.string :sec_user_mail
      t.string :sec_user_name
      t.string :rol, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :fotos_melon_sesiones, :token, unique: true
    add_index :fotos_melon_sesiones, :sec_user_id
    add_index :fotos_melon_sesiones, :expires_at
  end
end