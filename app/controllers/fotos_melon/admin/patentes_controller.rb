module FotosMelon
  module Admin
    class PatentesController < BaseController
      def index
        @patentes = FotosMelon::Patente.order(:nombre)
        @patentes = @patentes.where("nombre LIKE ?", "%#{params[:q].to_s.upcase}%") if params[:q].present?
      end
    end
  end
end