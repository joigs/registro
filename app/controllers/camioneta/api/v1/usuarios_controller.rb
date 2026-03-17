module Camioneta
  module Api
    module V1
      class UsuariosController < ApplicationController
        before_action :require_login, only: [:actualizar_token]

        def login
          usuario = CheckUsuario.find_by(rut: params[:rut])
          if usuario
            render json: { success: true, usuario: usuario }, status: :ok
          else
            render json: { success: false, error: 'Usuario no encontrado' }, status: :not_found
          end
        end

        def index
          usuarios = CheckUsuario.all
          render json: usuarios, status: :ok
        end

        def show
          usuario = CheckUsuario.find(params[:id])
          render json: usuario, status: :ok
        end

        def actualizar_token
          @current_usuario.update(push_token: params[:push_token])
          render json: { success: true }, status: :ok
        end
      end
    end
  end
end