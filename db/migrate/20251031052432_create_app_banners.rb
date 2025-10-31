class CreateAppBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :app_banners do |t|
      t.string  :kind, null: false          # "inline" | "modal"
      t.text    :message, null: false
      t.string  :link_url
      t.string  :link_label
      t.boolean :enabled, null: false, default: true
      t.boolean :admin_only, null: false, default: false

      t.timestamps
    end

    add_index :app_banners, :kind
    add_index :app_banners, :enabled
    add_index :app_banners, :admin_only
  end
end
