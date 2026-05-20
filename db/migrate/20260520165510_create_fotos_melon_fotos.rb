class CreateFotosMelonFotos < ActiveRecord::Migration[7.1]
  def change
    create_table :fotos_melon_fotos do |t|
      t.references :fecha_carpeta, null: false,
                   foreign_key: { to_table: :fotos_melon_fechas },
                   index: true
      t.string :nombre, null: false
      t.bigint :subido_por_id, null: false
      t.string :subido_por_nombre

      t.timestamps
    end

    add_index :fotos_melon_fotos, :subido_por_id
  end
end