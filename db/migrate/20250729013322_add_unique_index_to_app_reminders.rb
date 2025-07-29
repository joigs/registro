class AddUniqueIndexToAppReminders < ActiveRecord::Migration[7.1]
  def change
    add_index :app_reminders, %i[app_user_id fecha moment], unique: true
  end
end
