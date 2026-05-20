# app/models/midatech/sec_user_role.rb
module Midatech
  class SecUserRole < ::SecondaryModels::SecUserRoleExternal
    belongs_to :sec_user, foreign_key: "SecUserId", class_name: "Midatech::SecUser", optional: true
    belongs_to :sec_role, foreign_key: "SecRoleId", class_name: "Midatech::SecRole", optional: true
  end
end