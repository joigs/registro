class CreateAppDailyLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :app_daily_logs do |t|
      t.references :app_user, null: false, foreign_key: true
      t.date       :fecha,     null: false

      t.datetime   :morning_at
      t.datetime   :evening_at

      t.boolean    :morning_done, null: false, default: false
      t.boolean    :evening_done, null: false, default: false

      t.timestamps
    end

    add_index :app_daily_logs, [:app_user_id, :fecha], unique: true
  end
end
