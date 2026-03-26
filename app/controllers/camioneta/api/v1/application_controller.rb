module Camioneta
  module Api
    module V1
      class ApplicationController < ActionController::API
        before_action :set_default_format

        private

        def set_default_format
          request.format = :json
        end

        def require_login
          header = request.headers["Authorization"]
          token = header.to_s.gsub("Bearer ", "").strip

          @current_usuario = Camioneta::CheckUsuario.find_by(id: token)

          render json: { error: "No autorizado" }, status: :unauthorized unless @current_usuario
        end
      end
    end
  end
end