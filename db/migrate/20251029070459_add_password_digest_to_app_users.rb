class AddPasswordDigestToAppUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :app_users, :password_digest, :string
    add_index  :app_users, :password_digest
  end
end
