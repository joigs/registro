module Camioneta
  module Api
    module V1
      class UsuariosController < ApplicationController
        def login
          usuario = Camioneta::CheckUsuario.find_by(rut: params[:rut])
          if usuario
            render json: { success: true, usuario: usuario }, status: :ok
          else
            render json: { success: false, error: 'Usuario no encontrado' }, status: :not_found
          end
        end

        def index
          usuarios = Camioneta::CheckUsuario.all
          render json: usuarios, status: :ok
        end

        def show
          usuario = Camioneta::CheckUsuario.find(params[:id])
          render json: usuario, status: :ok
        end
      end
    end
  end
end