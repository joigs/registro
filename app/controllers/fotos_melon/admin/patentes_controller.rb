module FotosMelon
  module Admin
    class PatentesController < BaseController
      before_action :set_patente, only: [:show, :update, :destroy]

      def index
        @patentes = FotosMelon::Patente.order(:nombre)
        if params[:q].present?
          @patentes = @patentes.where("nombre LIKE ?", "%#{params[:q].to_s.upcase}%")
        end
      end

      def show
        @fechas = @patente.fechas.order(fecha: :desc)
      end

      def create
        nombre = params[:nombre].to_s.strip.upcase
        if nombre.blank?
          redirect_to fotos_melon_admin_root_path, alert: "Debes ingresar un nombre de patente." and return
        end
        FotosMelon::Patente.create!(
          nombre: nombre,
          creado_por_id: current_sesion.sec_user_id,
          creado_por_nombre: current_sesion.sec_user_name
        )
        redirect_to fotos_melon_admin_root_path, notice: "Patente creada."
      rescue ActiveRecord::RecordNotUnique
        redirect_to fotos_melon_admin_root_path, alert: "Ya existe esa patente."
      end

      def update
        nombre = params[:nombre].to_s.strip.upcase
        confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
        if confirmacion != @patente.nombre
          redirect_to fotos_melon_admin_patente_path(@patente), alert: "Confirmación incorrecta." and return
        end
        @patente.update!(nombre: nombre)
        redirect_to fotos_melon_admin_patente_path(@patente), notice: "Patente renombrada."
      rescue ActiveRecord::RecordNotUnique
        redirect_to fotos_melon_admin_patente_path(@patente), alert: "Ya existe esa patente."
      end

      def destroy
        confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
        if confirmacion != @patente.nombre
          redirect_to fotos_melon_admin_root_path, alert: "Confirmación incorrecta." and return
        end
        @patente.fechas.find_each do |fc|
          fc.fotos.find_each { |f| f.imagen.purge_later if f.imagen.attached? }
        end
        @patente.destroy!
        redirect_to fotos_melon_admin_root_path, notice: "Patente eliminada."
      end

      private

      def set_patente
        @patente = FotosMelon::Patente.find(params[:id])
      end
    end
  end
end