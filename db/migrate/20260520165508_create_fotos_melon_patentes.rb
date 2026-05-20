class CreateFotosMelonPatentes < ActiveRecord::Migration[7.1]
  def change
    create_table :fotos_melon_patentes do |t|
      t.string :nombre, null: false
      t.bigint :creado_por_id, null: false
      t.string :creado_por_nombre

      t.timestamps
    end

    add_index :fotos_melon_patentes, :nombre, unique: true
    add_index :fotos_melon_patentes, :creado_por_id
  end
end