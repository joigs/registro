# app/models/midatech/sec_role.rb
module Midatech
  class SecRole < SecondaryBase
    self.table_name = "SecRole"
    self.primary_key = "SecRoleId"

    ROL_ADMINISTRADOR = "Administrador".freeze
    ROL_INSPECTOR     = "Inspector".freeze
  end
end

