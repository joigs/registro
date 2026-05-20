module FotosMelon

  class Descarga < ::ApplicationRecord
    self.table_name = "fotos_melon_descargas"

    TTL = 10.minutes

    validates :token, presence: true, uniqueness: true
    validates :ids_json, :sec_user_id, :expires_at, presence: true

    before_validation :generar_token, on: :create
    before_validation :setear_expiracion, on: :create

    scope :vigentes, -> { where("expires_at > ?", Time.current) }

    def vigente?
      expires_at.present? && expires_at > Time.current
    end

    def ids
      JSON.parse(ids_json.to_s)
    rescue JSON::ParserError
      []
    end

    def self.crear_para(sec_user_id:, ids:)
      create!(
        sec_user_id: sec_user_id,
        ids_json: ids.to_a.map(&:to_i).uniq.to_json
      )
    end

    def registrar_uso!
      update_columns(used_at: Time.current, hits: hits + 1)
    rescue StandardError
      nil
    end

    private

    def generar_token
      self.token = SecureRandom.urlsafe_base64(32) if token.blank?
    end

    def setear_expiracion
      self.expires_at ||= TTL.from_now
    end
  end
end
