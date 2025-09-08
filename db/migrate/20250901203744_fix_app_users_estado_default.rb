class FixAppUsersEstadoDefault < ActiveRecord::Migration[7.1]
  def change
    change_column_default :app_users, :estado, from: true, to: false
  end

end
