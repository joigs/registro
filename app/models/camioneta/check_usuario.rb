module Camioneta
  class CheckUsuario < ApplicationRecord
    self.table_name = "check_usuarios"

    has_many :check_notificaciones, foreign_key: 'check_usuario_id', dependent: :destroy
    has_many :check_checkeo_usuarios, foreign_key: 'check_usuario_id', dependent: :destroy
    has_many :check_checkeos, through: :check_checkeo_usuarios

    validates :rut, presence: true, uniqueness: true
    validates :nombre, presence: true
  end
end