module Camioneta
  module Api
    module V1
      class LogsOcultosController < ApplicationController
        before_action :require_login

        def create
          log = Camioneta::CheckLogOculto.new(log_params.merge(
            usuario_id_accion: @current_usuario.id,
            usuario_nombre: @current_usuario.nombre
          ))

          if log.save
            render json: log, status: :created
          else
            render json: { errors: log.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def log_params
          params.require(:log_oculto).permit(:accion_realizada, :patente_afectada)
        end
      end
    end
  end
end