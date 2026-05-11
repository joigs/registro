module Camioneta
  module Api
    module V1
      class UsuariosController < ApplicationController
        before_action :require_login, only: [:actualizar_token]

        # Campos seguros que devolvemos al cliente. Evitamos exponer
        # password_digest, confirmation_token, expo_push_token de Pausa, etc.
        PUBLIC_FIELDS = [:id, :rut, :nombre].freeze

        def login
          usuario = Pausa::AppUser.find_by(rut: params[:rut])
          if usuario
            render json: { success: true, usuario: usuario.as_json(only: PUBLIC_FIELDS) }, status: :ok
          else
            render json: { success: false, error: 'Usuario no encontrado' }, status: :not_found
          end
        end

        def index
          usuarios = Pausa::AppUser.all
          render json: usuarios.as_json(only: PUBLIC_FIELDS), status: :ok
        end

        def show
          usuario = Pausa::AppUser.find(params[:id])
          render json: usuario.as_json(only: PUBLIC_FIELDS), status: :ok
        end

        def actualizar_token
          @current_usuario.update(expo_push_token_camioneta: params[:push_token])
          render json: { success: true }, status: :ok
        end
      end
    end
  end
end