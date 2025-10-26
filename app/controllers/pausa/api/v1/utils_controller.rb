# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class UtilsController < ApplicationController
        # Ruta de prueba SIN AUTH (protegida por ?secret= en producción)
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages
        skip_before_action :authenticate!, raise: false

        # GET /pausa/api/v1/test_push?rut=20848288-2&title=Hola&body=Mensaje&moment=morning&secret=XXXX
        def send_now
          unless allowed_by_secret?
            return render json: { error: "No autorizado" }, status: :forbidden
          end

          rut    = params[:rut].to_s.strip
          title  = params[:title].presence || "Pausa activa"
          body   = params[:body].presence  || "Mensaje de prueba"

          user = Pausa::AppUser.find_by(rut: rut)
          return render json: { error: "Usuario no encontrado" }, status: :unprocessable_entity unless user

          token = user.expo_push_token
          return render json: { error: "Usuario sin token push" }, status: :unprocessable_entity if token.blank?



          resp = Notifier::Fcm.send_to(
            user,
            title: title,
            body:  body,
            data:  { screen: "PausaActiva", moment: (moment || "") }
          )

          Rails.logger.info("[test_push] ok rut=#{rut} user_id=#{user.id} resp=#{resp.inspect}")

          render json: { ok: true, user_id: user.id, rut: rut, moment: moment }
        rescue => e
          Rails.logger.error("[test_push] error: #{e.class}: #{e.message}")
          render json: { error: "Fallo al enviar notificación" }, status: :internal_server_error
        end

        private

        def allowed_by_secret?
          # En producción exige ?secret=TEST_PUSH_SECRET; en otros entornos, libre.
          return true unless Rails.env.production?
          provided = params[:secret].to_s
          expected = ENV["TEST_PUSH_SECRET"].to_s
          provided.present? && expected.present? &&
            ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        end
      end
    end
  end
end
