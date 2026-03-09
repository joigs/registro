module Camioneta
  class CheckPatente < ApplicationRecord
    self.table_name = "check_patentes"

    has_many :check_checkeos, foreign_key: 'check_patente_id', dependent: :destroy

    validates :codigo, presence: true, uniqueness: true
  end
end