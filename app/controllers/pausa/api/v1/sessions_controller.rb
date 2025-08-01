# app/controllers/pausa/api/v1/sessions_controller.rb
module Pausa
  module Api
    module V1
      class SessionsController < ApplicationController
        skip_before_action :verify_authenticity_token

        def create
          user = AppUser.find_by(rut: params[:rut])

          if user&.activo
            token = jwt_encode({ id: user.id })
            render json: { token:, admin: user.admin, creado: user.creado }, status: :created
          else
            render json: { error: "Rut inválido o usuario inactivo" }, status: :unauthorized
          end
        end

        private

        def jwt_encode(payload)
          JWT.encode(payload.merge(exp: 24.hours.from_now.to_i), Rails.application.credentials.jwt_secret)
        end
      end
    end
  end
end
