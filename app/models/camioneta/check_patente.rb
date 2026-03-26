module Camioneta
  class CheckPatente < ApplicationRecord
    self.table_name = "check_patentes"

    has_many :check_checkeos, foreign_key: 'check_patente_id', dependent: :destroy

    validates :codigo, presence: true, uniqueness: true



    def self.limpiar_huerfanas
      patentes_sin_chequeos = left_outer_joins(:check_checkeos).where(check_checkeos: { id: nil })

      cantidad = patentes_sin_chequeos.count
      patentes_sin_chequeos.destroy_all

      Rails.logger.info("[Camioneta::Cron] Se eliminaron #{cantidad} patentes sin inspecciones asociadas.")
    end
  end
end