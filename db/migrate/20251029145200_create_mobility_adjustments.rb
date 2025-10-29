class CreateMobilityAdjustments < ActiveRecord::Migration[7.1]
  def change
    create_table :mobility_adjustments do |t|
      t.string :empresa
      t.string :mandante_rut
      t.string :mandante_nombre
      t.decimal :uf, precision: 10, scale: 4
      t.integer :servicios
      t.date :fecha
      t.string :notas

      t.timestamps
    end
  end
end
