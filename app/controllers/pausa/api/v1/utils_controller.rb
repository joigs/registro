# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class UtilsController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages
        skip_before_action :authenticate!, raise: false

        # GET /pausa/api/v1/notify?rut=20848288-2&title=Hola&body=Mensaje&secret=XXXX
        # También acepta ?token=EXPO_PUSH_TOKEN en lugar de ?rut=
        def notify
          return render json: { error: "No autorizado" }, status: :forbidden unless allowed_by_secret?

          title = params[:title].presence || "Pausa activa"
          body  = params[:body].presence  || "Mensaje de prueba"
          data  = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}

          user_like =
            if params[:rut].present?
              u = Pausa::AppUser.find_by(rut: params[:rut].to_s.strip)
              return render json: { error: "Usuario no encontrado" }, status: :unprocessable_entity unless u
              return render json: { error: "Usuario sin token push" }, status: :unprocessable_entity if u.expo_push_token.blank?
              u
            elsif params[:token].present?
              # Permitir enviar directo por token
              Struct.new(:expo_push_token).new(params[:token].to_s.strip)
            else
              return render json: { error: "Falta rut o token" }, status: :unprocessable_entity
            end

          resp = Notifier::Fcm.send_to(user_like, title: title, body: body, data: data)
          Rails.logger.info("[utils#notify] push ok resp=#{resp.inspect}")

          render json: { ok: true }
        rescue => e
          Rails.logger.error("[utils#notify] error: #{e.class}: #{e.message}")
          render json: { error: "Fallo al enviar notificación" }, status: :internal_server_error
        end

        private

        def allowed_by_secret?
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
