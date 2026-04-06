module Camioneta
  module Api
    module V1
      class PatentesController < ApplicationController
        before_action :require_login

        def index
          patentes = Camioneta::CheckPatente.order(created_at: :desc)
          render json: patentes, status: :ok
        end
        def show
          patente = Camioneta::CheckPatente.find(params[:id])

          fecha_inicio = case params[:periodo]
                         when 'semana' then 1.week.ago.beginning_of_day
                         when 'mes' then 1.month.ago.beginning_of_day
                         when 'ano'
                           year = params[:ano].present? ? params[:ano].to_i : Time.current.year
                           Time.zone.local(year, 1, 1).beginning_of_day
                         else 1.month.ago.beginning_of_day
                         end

          fecha_fin = if params[:periodo] == 'ano'
                        year = params[:ano].present? ? params[:ano].to_i : Time.current.year
                        Time.zone.local(year, 12, 31).end_of_day
                      else
                        Time.current.end_of_day
                      end

          checkeos = patente.check_checkeos
                            .where(fecha_chequeo: fecha_inicio..fecha_fin)
                            .includes(:check_usuarios)

          ultima = patente.check_checkeos
                          .order(fecha_chequeo: :desc)
                          .includes(:check_usuarios)
                          .first

          render json: {
            patente: patente,
            fecha_servidor: Time.current.to_date,
            checkeos: checkeos.as_json(include: :check_usuarios),
            ultima_inspeccion: ultima&.as_json(include: :check_usuarios)
          }, status: :ok
        end
        def create
          patente = CheckPatente.new(patente_params)
          if patente.save
            render json: patente, status: :created
          else
            render json: { errors: patente.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          patente = CheckPatente.find(params[:id])

          CheckLogOculto.create!(
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