class CreateFotosMelonFechas < ActiveRecord::Migration[7.1]
  def change
    create_table :fotos_melon_fechas do |t|
      t.references :patente, null: false,
                   foreign_key: { to_table: :fotos_melon_patentes },
                   index: true
      t.date :fecha, null: false
      t.string :nombre_personalizado
      t.bigint :creado_por_id, null: false
      t.string :creado_por_nombre

      t.timestamps
    end

    add_index :fotos_melon_fechas, [:patente_id, :fecha], unique: true
  end
end