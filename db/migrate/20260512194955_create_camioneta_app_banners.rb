class CreateCamionetaAppBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :camioneta_app_banners, charset: "utf8mb4", collation: "utf8mb4_general_ci" do |t|
      t.string :kind, null: false
      t.text :message, null: false
      t.string :link_url
      t.string :link_label
      t.boolean :enabled, default: true, null: false
      t.integer :version, default: 1, null: false
      t.timestamps

      t.index :kind
      t.index :enabled
      t.index :version
    end
  end
end