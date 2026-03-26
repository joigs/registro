module Camioneta
  class CheckCheckeo < ApplicationRecord
    self.table_name = "check_checkeos"

    belongs_to :check_patente, class_name: "Camioneta::CheckPatente"

    has_many :check_checkeo_usuarios, foreign_key: "check_checkeo_id", dependent: :destroy
    has_many :check_usuarios, through: :check_checkeo_usuarios

    enum extintor: {
      extintor_si: 0,
      extintor_no: 1,
      extintor_vencido: 2
    }

    enum kit_derrame: {
      kit_si: 0,
      kit_no: 1,
      kit_falta_pala: 2,
      kit_falta_bolsa: 3
    }

    BOOLEAN_FIELDS = %w[
      botiquin
      gata
      cadenas
      llave_rueda
      antena_radio
      permiso_circulacion
      revision_tecnica
      soap
      alcohol
      protector_solar
      carpeta
      panos_limpieza
      conos
      radio_comunicacion
      espejo_inspeccion
      toldo
      pie_de_metro
      tintas
      arnes
    ].freeze

    INTEGER_FIELDS = %w[
      falta_diclofenaco_cant
      falta_guantes_cant
      falta_parche_curita_cant
      falta_gasa_cant
      falta_venda_cant
      falta_suero_cant
      falta_tela_adhesiva_cant
      falta_palitos_cant
    ].freeze

    ENUM_FIELDS = %w[
      extintor
      kit_derrame
    ].freeze

    REALTIME_EDITABLE_FIELDS = (BOOLEAN_FIELDS + INTEGER_FIELDS + ENUM_FIELDS).freeze
    REQUIRED_FIELDS = REALTIME_EDITABLE_FIELDS.freeze

    validate :unico_chequeo_activo_por_dia, on: :create

    def unico_chequeo_activo_por_dia
      if Camioneta::CheckCheckeo.where(check_patente_id: check_patente_id, fecha_chequeo: fecha_chequeo).exists?
        errors.add(:fecha_chequeo, "Ya existe una inspección activa para esta patente hoy")
      end
    end

    def asociado?(usuario_o_id)
      usuario_id =
        case usuario_o_id
        when Camioneta::CheckUsuario then usuario_o_id.id
        else usuario_o_id
        end

      return false if usuario_id.blank?

      check_checkeo_usuarios.exists?(check_usuario_id: usuario_id)
    end

    def campos_obligatorios_completos?
      REQUIRED_FIELDS.all? do |field|
        value = public_send(field)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
    end

    def apply_realtime_update!(field, raw_value)
      field = field.to_s

      unless REALTIME_EDITABLE_FIELDS.include?(field)
        raise ArgumentError, "Campo no permitido"
      end

      casted_value = cast_realtime_value(field, raw_value)

      assign_attributes(field => casted_value)
      self.completado = campos_obligatorios_completos?

      save!
    end

    def cast_realtime_value(field, raw_value)
      if BOOLEAN_FIELDS.include?(field)
        ActiveModel::Type::Boolean.new.cast(raw_value)
      elsif INTEGER_FIELDS.include?(field)
        value = raw_value.to_s.strip
        value == "" ? nil : value.to_i
      elsif field == "extintor"
        cast_enum_value(self.class.extintors, raw_value, "extintor")
      elsif field == "kit_derrame"
        cast_enum_value(self.class.kit_derrames, raw_value, "kit_derrame")
      else
        raise ArgumentError, "Campo no soportado"
      end
    end

    def cast_enum_value(enum_hash, raw_value, field_name)
      value = raw_value.to_s

      return value if enum_hash.key?(value)

      if value.match?(/\A\d+\z/)
        key = enum_hash.key(value.to_i)
        return key if key.present?
      end

      raise ArgumentError, "Valor inválido para #{field_name}"
    end

    def listos_para_eliminar?
      check_checkeo_usuarios.all?(&:aprueba_eliminar?)
    end

    def conforme
      return false unless completado

      extintor_ok = extintor == "extintor_si" || extintor == 0 || extintor == "0"
      kit_ok = kit_derrame == "kit_si" || kit_derrame == 0 || kit_derrame == "0"

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