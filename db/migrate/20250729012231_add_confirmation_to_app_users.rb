class AddConfirmationToAppUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :app_users, :confirmation_token, :string
    add_column :app_users, :confirmed_at, :datetime
    add_index :app_users, :confirmation_token, unique: true

  end
end
