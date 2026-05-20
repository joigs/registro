module FotosMelon
  class Sesion < ::ApplicationRecord
    self.table_name = "fotos_melon_sesiones"

    INACTIVIDAD_MAXIMA = 6.months

    ROL_ADMINISTRADOR = "administrador".freeze
    ROL_INSPECTOR     = "inspector".freeze

    validates :token, presence: true, uniqueness: true
    validates :sec_user_id, :rol, presence: true

    scope :activas, -> {
      where(closed_at: nil)
        .where("last_seen_at IS NULL OR last_seen_at > ?", INACTIVIDAD_MAXIMA.ago)
    }

    before_validation :generar_token, on: :create
    before_validation :inicializar_actividad, on: :create

    def vigente?
      return false if closed_at.present?
      ref = last_seen_at || created_at
      ref.present? && ref > INACTIVIDAD_MAXIMA.ago
    end

    def administrador?
      rol == ROL_ADMINISTRADOR
    end

    def inspector?
      rol == ROL_INSPECTOR
    end

    # Logout manual.
    def cerrar!
      update_columns(closed_at: Time.current)
    rescue StandardError
      nil
    end

    def tocar!
      update_columns(last_seen_at: Time.current)
    rescue StandardError
      nil
    end

    private

    def generar_token
      self.token = SecureRandom.urlsafe_base64(48) if token.blank?
    end

    def inicializar_actividad
      now = Time.current
      self.last_seen_at ||= now
      self.expires_at = nil if respond_to?(:expires_at=) && expires_at.nil?
    end
  end
end
