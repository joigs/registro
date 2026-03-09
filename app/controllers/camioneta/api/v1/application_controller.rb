module Camioneta
  module Api
    module V1
      class ApplicationController < ActionController::API
        def require_login
          usuario_id = request.headers['Authorization']
          @current_usuario = CheckUsuario.find_by(id: usuario_id)
          render json: { error: 'No autorizado' }, status: :unauthorized unless @current_usuario
        end
      end
    end
  end
end