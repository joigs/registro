module Camioneta
  module Api
    module V1
      class NotificacionesController < ApplicationController
        before_action :require_login

        def index
          notificaciones = Camioneta::CheckNotificacion.where(check_usuario_id: @current_usuario.id).order(created_at: :desc)
          render json: notificaciones, status: :ok
        end

        def marcar_leida
          notificacion = Camioneta::CheckNotificacion.find_by!(id: params[:id], check_usuario_id: @current_usuario.id)
          notificacion.update(leida: true)
          render json: notificacion, status: :ok
        end
      end
    end
  end
end