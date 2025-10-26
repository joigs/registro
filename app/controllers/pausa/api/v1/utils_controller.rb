# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class UtilsController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages
        skip_before_action :authenticate! rescue nil

        def notify
          rut = params[:rut].to_s.strip
          msg = params[:msg].presence || "Notificación de prueba"

          user = AppUser.find_by(rut: rut)
          return render json: { ok: false, error: "Usuario no encontrado" }, status: 404 unless user
          return render json: { ok: false, error: "Sin expo_push_token" }, status: 422 unless user.expo_push_token.present?

          Notifier::Fcm.send_to(
            user,
            title: "Pausa activa",
            body:  msg,
            data:  { screen: "PausaActiva", moment: "morning" }
          )

          render json: { ok: true, user_id: user.id, rut: user.rut }
        rescue => e
          render json: { ok: false, error: e.message }, status: 500
        end
      end
    end
  end
end
