class CreateAppReminders < ActiveRecord::Migration[7.1]
  def change
    create_table :app_reminders do |t|
      t.references :app_user, null: false, foreign_key: true
      t.date :fecha
      t.string :moment
      t.datetime :sent_at
      t.datetime :opened_at

      t.timestamps
    end
  end
end
