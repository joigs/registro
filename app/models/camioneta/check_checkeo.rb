module Camioneta
  class CheckCheckeo < ApplicationRecord
    self.table_name = "check_checkeos"

    belongs_to :check_patente, class_name: 'Camioneta::CheckPatente'

    has_many :check_checkeo_usuarios, foreign_key: 'check_checkeo_id', dependent: :destroy
    has_many :check_usuarios, through: :check_checkeo_usuarios

    enum extintor: { extintor_si: 0, extintor_no: 1, extintor_vencido: 2 }
    enum kit_derrame: { kit_si: 0, kit_no: 1, kit_falta_pala: 2, kit_falta_bolsa: 3 }


    validate :unico_chequeo_activo_por_dia, on: :create

    def unico_chequeo_activo_por_dia
      if CheckCheckeo.where(check_patente_id: check_patente_id, fecha_chequeo: fecha_chequeo).exists?
        errors.add(:fecha_chequeo, "Ya existe un chequeo activo para esta patente hoy")
      end
    end

    def listos_para_eliminar?
      check_checkeo_usuarios.all?(&:aprueba_eliminar?)
    end
  end
end