# app/models/midatech/sec_user.rb
module Midatech
  class SecUser < SecondaryBase
    self.table_name = "SecUser"
    self.primary_key = "SecUserId"

    has_many :sec_user_roles,
             foreign_key: "SecUserId",
             class_name: "Midatech::SecUserRole"
    has_many :sec_roles,
             through: :sec_user_roles,
             source: :sec_role

    def roles
      sec_roles.pluck(:SecRoleName)
    rescue StandardError => e
      Rails.logger.error("[Midatech::SecUser#roles] #{e.class}: #{e.message}")
      []
    end

    def authenticate_password(password)
      return false if password.blank?
      self.SecUserPassword.to_s == password.to_s
    end
  end
end


