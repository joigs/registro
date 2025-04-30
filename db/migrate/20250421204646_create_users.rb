class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, charset: 'utf8mb4', collation: 'utf8mb4_general_ci' do |t|
      t.string   :username, null: false
      t.string   :password_digest, null: false
      t.boolean  :admin, default: false
      t.datetime :deleted_at
      t.boolean  :super, default: false, null: false

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :deleted_at
  end
end
