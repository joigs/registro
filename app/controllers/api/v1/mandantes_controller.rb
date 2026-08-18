module Api
  module V1
    class MandantesController < BaseController
      def index
        scope = SecondaryModels::CerManExternal.all

        if params[:q].present?
          term = "%#{params[:q].to_s.strip}%"
          scope = scope.where("CerMan.CerManNombre LIKE :t OR CerMan.CerManRut LIKE :t", t: term)
        end

        rows = scope.order(Arel.sql("CerMan.CerManNombre ASC"))
                    .pluck(:CerManRut, :CerManNombre, :CerManRutN)

        data = rows.map do |rut, nombre, rut_n|
          {
            rut:    rut.to_s.strip,
            nombre: nombre.to_s.strip,
            rut_n:  rut_n
          }
        end

        render json: { count: data.size, data: data }, status: :ok
      end
    end
  end
end