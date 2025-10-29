# app/controllers/pausa/api/v1/sessions_controller.rb
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

          unless user&.activo && user&.creado
            return render json: { error: "Rut inválido, usuario inactivo o no aprobado" }, status: :unauthorized
          end

          if user.admin?
            pwd = params[:password] || params.dig(:session, :password)

            if pwd.blank?
              return render json: {
                error: "Contraseña requerida para administradores",
                error_code: "password_required",
                admin: true
              }, status: :unauthorized
            end

            unless user.authenticate(pwd)
              return render json: {
                error: "Contraseña inválida",
                error_code: "invalid_password",
                admin: true
              }, status: :unauthorized
            end
          end

          token = jwt_encode({ id: user.id })
          render json: { token: token, admin: user.admin, creado: user.creado }, status: :ok
        end

        private

        def jwt_secret
          Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"] || Rails.application.secret_key_base
        end

        def jwt_encode(payload)
          # 90 días
          JWT.encode(payload.merge(exp: 90.days.from_now.to_i), jwt_secret, "HS256")
        end
      end
    end
  end
end
