class CreatePausaAppUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :app_users do |t|
      t.string  :nombre, null: false
      t.string  :rut,    null: false
      t.string  :correo, null: false

      t.boolean :admin,   null: false, default: false
      t.boolean :activo,  null: false, default: true
      t.boolean :estado,  null: false, default: true
      t.boolean :creado,  null: false, default: false

      t.timestamps
    end

    add_index :app_users, :rut, unique: true
  end
end
