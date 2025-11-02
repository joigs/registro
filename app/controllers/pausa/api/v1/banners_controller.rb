# app/controllers/pausa/api/v1/banners_controller.rb
# frozen_string_literal: true
require "jwt"

module Pausa
  module Api
    module V1
      class BannersController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages
        before_action :authenticate!

        def index
          is_admin = @current_user&.admin? || false

          scoped = Pausa::AppBanner.enabled.for_admin(is_admin)
          inline = scoped.for_kind("inline").order(created_at: :desc).limit(1).first
          modal  = scoped.for_kind("modal").order(created_at: :desc).limit(1).first

          render json: {
            inline: inline ? serialize(inline) : nil,
            modal:  modal  ? serialize(modal)  : nil
          }
        rescue => e
          # Si algo falla, devolvemos un mensaje claro (y no un 500 silencioso)
          Rails.logger.error("[banners#index] #{e.class}: #{e.message}")
          render json: { error: "failed", message: e.message }, status: :internal_server_error
        end

        private

        def serialize(b)
          {
            id: b.id,
            kind: b.kind,
            message: b.message,
            link_url: b.link_url,
            link_label: b.link_label,
            enabled: b.enabled,
            admin_only: b.admin_only,
            created_at: b.created_at
          }
        end

        # ====== Auth mínima (copiada de AppUsersController) ======
        def jwt_secret
          Rails.application.credentials.jwt_secret ||
            ENV["JWT_SECRET"] ||
            Rails.application.secret_key_base
        end

        def authenticate!
          header = request.headers["Authorization"]
          unless header&.start_with?("Bearer ")
            render json: { error: "Falta token" }, status: :unauthorized
            return
          end

          token = header.split(" ").last
          payload = JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
          @current_user = AppUser.find(payload["id"])
        rescue JWT::ExpiredSignature
          render json: { error: "Token expirado" }, status: :unauthorized
        rescue StandardError => e
          Rails.logger.warn("[banners#authenticate!] #{e.class}: #{e.message}")
          render json: { error: "Token inválido" }, status: :unauthorized
        end
      end
    end
  end
end
