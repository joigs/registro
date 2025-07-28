
module Pausa
  class AppUser < ApplicationRecord
    self.table_name = "app_users"

    EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.freeze

    # ── Validaciones ────────────────────────────────────────────────
    validates :nombre, :rut, :correo, presence: true
    validates :rut, uniqueness: true
    validates :correo, format: { with: EMAIL_REGEX }
  end
end
