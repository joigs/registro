# app/models/midatech/sec_role.rb
module Midatech
  class SecRole < ::SecondaryModels::SecRoleExternal
    ROL_ADMINISTRADOR = "Administrador".freeze
    ROL_INSPECTOR     = "Inspector".freeze
  end
end