class CreateFotosMelonDescargas < ActiveRecord::Migration[7.1]
  def change
    create_table :fotos_melon_descargas do |t|
      t.string  :token,        null: false
      t.text    :ids_json,     null: false
      t.bigint  :sec_user_id,  null: false
      t.datetime :expires_at,  null: false
      t.datetime :used_at
      t.integer :hits, default: 0, null: false

      t.timestamps
    end

    add_index :fotos_melon_descargas, :token, unique: true
    add_index :fotos_melon_descargas, :expires_at
  end
end