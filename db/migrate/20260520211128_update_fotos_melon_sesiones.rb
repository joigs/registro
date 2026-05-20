class UpdateFotosMelonSesiones < ActiveRecord::Migration[7.1]
  def change
    change_column_null :fotos_melon_sesiones, :expires_at, true
    add_column :fotos_melon_sesiones, :closed_at, :datetime
    add_index  :fotos_melon_sesiones, :last_seen_at
    add_index  :fotos_melon_sesiones, :closed_at
  end
end