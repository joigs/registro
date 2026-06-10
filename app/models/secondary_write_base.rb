# app/models/secondary_write_base.rb
class SecondaryWriteBase < ActiveRecord::Base
  self.abstract_class = true

  establish_connection(
    adapter:  'mysql2',
    host:     ENV['SECONDARY_DB_HOST'],
    port:     ENV['SECONDARY_DB_PORT'],
    database: ENV['SECONDARY_DB_NAME'],
    username: ENV['SECONDARY_DB_WRITE_USER'],
    password: ENV['SECONDARY_DB_WRITE_PASS'],
    encoding: 'utf8mb4',
    pool:  5,
    timeout: 5000
  )
end