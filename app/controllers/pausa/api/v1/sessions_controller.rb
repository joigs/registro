# frozen_string_literal: true

require "jwt"

module Pausa
  module Api
    module V1
      class SessionsController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        def create
          rut = params[:rut] || params.dig(:session, :rut)
          return render(json: { error: "Falta rut" }, status: :unprocessable_entity) if rut.blank?

          user = AppUser.find_by(rut: rut)

          if user&.activo && user.creado
            token = jwt_encode({ id: user.id })
            render json: { token: token, admin: user.admin, creado: user.creado }, status: :ok
          else
            render json: { error: "Rut inválido, usuario inactivo o no aprobado" }, status: :unauthorized
          end
        end

        private

        # ─── JWT ────────────────────────────────────────────────────────────────
        def jwt_secret
          Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"] || Rails.application.secret_key_base
        end

        def jwt_encode(payload)
          JWT.encode(payload.merge(exp: 24.hours.from_now.to_i), jwt_secret, "HS256")
        end
      end
    end
  end
end
