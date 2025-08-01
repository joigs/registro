class AddPushTokenToAppUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :app_users, :expo_push_token, :string
    add_index :app_users, :expo_push_token
  end
end
