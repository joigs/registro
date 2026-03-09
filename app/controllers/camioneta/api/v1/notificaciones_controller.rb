module Camioneta
  module Api
    module V1
      class NotificacionesController < ApplicationController
        before_action :require_login

        def index
          notificaciones = @current_usuario.check_notificaciones.order(created_at: :desc)
          render json: notificaciones, status: :ok
        end

        def marcar_leida
          notificacion = @current_usuario.check_notificaciones.find(params[:id])
          notificacion.update(leida: true)
          render json: notificacion, status: :ok
        end
      end
    end
  end
end