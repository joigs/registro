# app/models/secondary_base.rb
require 'dotenv/load' if Rails.env.development?

class SecondaryBase < ActiveRecord::Base
  self.abstract_class = true

  establish_connection(
    adapter:  'mysql2',
    host:     ENV['SECONDARY_DB_HOST'],
    port:     ENV['SECONDARY_DB_PORT'],
    database: ENV['SECONDARY_DB_NAME'],
    username: ENV['SECONDARY_DB_USER'],
    password: ENV['SECONDARY_DB_PASS'],
    encoding: 'utf8mb4',
    pool:  5,
    timeout: 5000
  )



  def readonly?
    true
  end

  def before_destroy
    raise ActiveRecord::ReadOnlyRecord
  end
end
