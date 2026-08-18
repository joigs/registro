module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      rescue_from StandardError do |e|
        Rails.logger.error("[API v1] #{e.class}: #{e.message}")
        render json: { error: "internal_server_error" }, status: :internal_server_error
      end

      private

      def authenticate_api_key!
        provided = request.headers["X-Registro-Api-Key"].to_s
        return render_unauthorized if provided.blank?
        return render_unauthorized unless valid_api_key?(provided)
      end

      def valid_api_key?(provided)
        allowed_api_keys.any? do |key|
          ActiveSupport::SecurityUtils.secure_compare(
            ::Digest::SHA256.hexdigest(provided),
            ::Digest::SHA256.hexdigest(key)
          )
        end
      end

      def allowed_api_keys
        @allowed_api_keys ||= ENV.fetch("REGISTRO_API_MANDANTES_KEYS", "")
                                 .split(",").map(&:strip).reject(&:blank?)
      end

      def render_unauthorized
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end
  end
end