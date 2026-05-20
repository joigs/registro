module FotosMelon
  module Api
    module V1
      class ApplicationController < ActionController::API
        include ActionController::Live

        before_action :set_default_format

        rescue_from ActiveRecord::RecordNotFound,    with: :render_not_found
        rescue_from ActiveRecord::RecordInvalid,     with: :render_unprocessable
        rescue_from ActionController::ParameterMissing, with: :render_bad_request

        private

        def set_default_format
          request.format = :json
        end

        def require_login
          header = request.headers["Authorization"].to_s
          token  = header.gsub(/^Bearer\s+/i, "").strip
          if token.blank?
            return render json: { error: "No autorizado" }, status: :unauthorized
          end

          sesion = FotosMelon::Sesion.find_by(token: token)
          unless sesion && sesion.vigente?
            return render json: { error: "Sesión expirada o inválida" }, status: :unauthorized
          end

          @current_sesion    = sesion
          @current_user_id   = sesion.sec_user_id
          @current_user_name = sesion.sec_user_name
          @current_rol       = sesion.rol
          sesion.tocar!
        end

        def require_admin
          return if @current_sesion&.administrador?
          render json: { error: "Solo administradores" }, status: :forbidden
        end

        def fmt_fecha(d)
          return nil if d.blank?
          d.strftime("%d/%m/%Y")
        end

        def fmt_fecha_hora(t)
          return nil if t.blank?
          t.in_time_zone.strftime("%d/%m/%Y %H:%M")
        end

        def render_not_found(_e)
          render json: { error: "No encontrado" }, status: :not_found
        end

        def render_unprocessable(e)
          render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end

        def render_bad_request(e)
          render json: { error: e.message }, status: :bad_request
        end
      end
    end
  end
end