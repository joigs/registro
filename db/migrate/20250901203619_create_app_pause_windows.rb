class CreateAppPauseWindows < ActiveRecord::Migration[7.1]
  def change
    create_table :app_pause_windows do |t|
      t.string  :moment, null: false
      t.integer :hour,   null: false, default: 11
      t.integer :minute, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :app_pause_windows, :moment, unique: true
  end
end
