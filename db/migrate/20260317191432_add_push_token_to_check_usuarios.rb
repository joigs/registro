class AddPushTokenToCheckUsuarios < ActiveRecord::Migration[7.1]
  def change
    add_column :check_usuarios, :push_token, :string
  end
end
