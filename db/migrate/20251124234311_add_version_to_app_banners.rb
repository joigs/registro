class AddVersionToAppBanners < ActiveRecord::Migration[7.1]
  def change
    add_column :app_banners, :version, :integer, null: false, default: 1
  end
end
