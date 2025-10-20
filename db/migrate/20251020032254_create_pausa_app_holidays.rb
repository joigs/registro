class CreatePausaAppHolidays < ActiveRecord::Migration[7.1]
  def change
    create_table :pausa_app_holidays do |t|
      t.date :fecha, null: false

      t.timestamps
    end
    add_index :pausa_app_holidays, :fecha, unique: true
  end
end
