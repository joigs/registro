# app/models/midatech/sec_user_role.rb
module Midatech
  class SecUserRole < SecondaryBase
    self.table_name = "SecUserRole"
    self.primary_key = nil

    belongs_to :sec_user, foreign_key: "SecUserId", class_name: "Midatech::SecUser", optional: true
    belongs_to :sec_role, foreign_key: "SecRoleId", class_name: "Midatech::SecRole", optional: true
  end
end