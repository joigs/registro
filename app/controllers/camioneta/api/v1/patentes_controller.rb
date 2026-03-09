module Camioneta
  module Api
    module V1
      class PatentesController < ApplicationController
        before_action :require_login

        def index
          patentes = Camioneta::CheckPatente.all
          render json: patentes, status: :ok
        end

        def show
          patente = Camioneta::CheckPatente.find(params[:id])

          fecha_inicio = case params[:periodo]
                         when 'semana' then Time.current.beginning_of_week
                         when 'mes' then Time.current.beginning_of_month
                         when 'ano' then Time.current.beginning_of_year
                         else Time.current.beginning_of_month
                         end

          checkeos = patente.check_checkeos
                            .where(fecha_chequeo: fecha_inicio..Time.current.end_of_day)
                            .includes(:check_usuarios)

          render json: {
            patente: patente,
            checkeos: checkeos.as_json(include: :check_usuarios)
          }, status: :ok
        end

        def create
          patente = Camioneta::CheckPatente.new(patente_params)
          if patente.save
            render json: patente, status: :created
          else
            render json: { errors: patente.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          patente = Camioneta::CheckPatente.find(params[:id])

          Camioneta::CheckLogOculto.create!(
            usuario_id_accion: @current_usuario.id,
            usuario_nombre: @current_usuario.nombre,
            accion_realizada: "Eliminacion de Patente",
            patente_afectada: patente.codigo
          )

          patente.destroy
          head :no_content
        end

        private

        def patente_params
          params.require(:patente).permit(:codigo)
        end
      end
    end
  end
end