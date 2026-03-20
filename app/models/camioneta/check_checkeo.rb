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
        errors.add(:fecha_chequeo, "Ya existe una inspeción activa para esta patente hoy")
      end
    end

    def listos_para_eliminar?
      check_checkeo_usuarios.all?(&:aprueba_eliminar?)
    end
    def conforme
      return false unless completado

      extintor_ok = extintor == 'extintor_si' || extintor == 0 || extintor == '0'
      kit_ok = kit_derrame == 'kit_si' || kit_derrame == 0 || kit_derrame == '0'

      extintor_ok && kit_ok &&
        botiquin && gata && cadenas && llave_rueda && antena_radio &&
        permiso_circulacion && revision_tecnica && soap && alcohol &&
        protector_solar && carpeta && panos_limpieza && conos &&
        radio_comunicacion && espejo_inspeccion && toldo && pie_de_metro &&
        tintas && arnes &&
        falta_diclofenaco_cant.to_i >= 3 && falta_guantes_cant.to_i >= 3 &&
        falta_parche_curita_cant.to_i >= 5 && falta_gasa_cant.to_i >= 10 &&
        falta_venda_cant.to_i >= 1 && falta_suero_cant.to_i >= 3 &&
        falta_tela_adhesiva_cant.to_i >= 1 && falta_palitos_cant.to_i >= 6
    end
  end
end