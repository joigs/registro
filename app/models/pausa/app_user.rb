module Pausa
  class AppUser < ApplicationRecord
    self.table_name = "app_users"

    has_many :app_daily_logs, class_name: "Pausa::AppDailyLog", dependent: :destroy


    has_many :check_notificaciones,
             class_name: "Camioneta::CheckNotificacion",
             foreign_key: "app_user_id",
             dependent: :destroy
    has_many :check_checkeo_usuarios,
             class_name: "Camioneta::CheckCheckeoUsuario",
             foreign_key: "app_user_id",
             dependent: :destroy
    has_many :check_checkeos,
             through: :check_checkeo_usuarios,
             class_name: "Camioneta::CheckCheckeo"

    EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.freeze

    # ── Validaciones ────────────────────────────────────────────────
    validates :nombre, :rut, :correo, presence: true
    validates :rut, uniqueness: true
    validates :correo, format: { with: EMAIL_REGEX }

    has_secure_password validations: false
  end
end