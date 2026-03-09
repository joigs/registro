module Camioneta
  module Api
    module V1
      class ApplicationController < ActionController::API
        def require_login
          header = request.headers['Authorization']
          token = header.to_s.gsub('Bearer ', '').strip
          @current_usuario = Camioneta::CheckUsuario.find_by(id: token)
          render json: { error: 'No autorizado' }, status: :unauthorized unless @current_usuario
        end
      end
    end
  end
end