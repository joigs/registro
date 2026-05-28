module FotosMelon
  module Admin
    class FechasController < BaseController
      before_action :set_patente, only: [:create, :index]
      before_action :set_fecha, only: [:show, :update, :destroy, :descargar]


      def show
        @fotos = @fecha.fotos.includes(imagen_attachment: :blob).order(:created_at)
      end

      def create
        fecha_dia = parsear_fecha(params[:fecha])
        unless fecha_dia
          redirect_to fotos_melon_admin_patente_path(@patente), alert: "Fecha inválida." and return
        end
        @patente.fechas.create!(
          fecha: fecha_dia,
          creado_por_id: current_sesion.sec_user_id,
          creado_por_nombre: current_sesion.sec_user_name
        )
        redirect_to fotos_melon_admin_patente_path(@patente), notice: "Carpeta de fecha creada."
      rescue ActiveRecord::RecordNotUnique
        redirect_to fotos_melon_admin_patente_path(@patente), alert: "Ya existe una carpeta para esa fecha."
      end

      def update
        confirmacion = params[:confirmacion_nombre].to_s.strip
        if confirmacion != @fecha.nombre_mostrado.to_s.strip
          redirect_to fotos_melon_admin_fecha_path(@fecha), alert: "Confirmación incorrecta." and return
        end
        @fecha.update!(nombre_personalizado: params[:nombre_personalizado])
        redirect_to fotos_melon_admin_fecha_path(@fecha), notice: "Carpeta renombrada."
      end

      def destroy
        confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
        if confirmacion != @fecha.patente.nombre
          redirect_to fotos_melon_admin_fecha_path(@fecha), alert: "Confirmación incorrecta." and return
        end
        patente = @fecha.patente
        @fecha.fotos.find_each { |f| f.imagen.purge_later if f.imagen.attached? }
        @fecha.destroy!
        redirect_to fotos_melon_admin_patente_path(patente), notice: "Carpeta eliminada."
      end

      def descargar
        fotos = @fecha.fotos.includes(imagen_attachment: :blob).to_a.select { |f| f.imagen.attached? }
        if fotos.empty?
          redirect_to fotos_melon_admin_fecha_path(@fecha), alert: "Carpeta vacía." and return
        end
        require "zip"
        tmp = Tempfile.new(["carpeta_", ".zip"], binmode: true)
        tmp.close
        nombres = Hash.new(0)
        service = ActiveStorage::Blob.service
        ::Zip::File.open(tmp.path, Zip::File::CREATE) do |zip|
          fotos.each do |foto|
            ruta = service.path_for(foto.imagen.blob.key)
            next unless File.exist?(ruta)
            base = foto.nombre_descarga
            nombres[base] += 1
            final = nombres[base] == 1 ? base : numerar(base, nombres[base])
            zip.add(final, ruta)
          end
        end
        carpeta = @fecha.nombre_personalizado.presence || @fecha.fecha.strftime("%d-%m-%Y")
        send_file tmp.path, type: "application/zip", disposition: "attachment",
                  filename: "#{@fecha.patente.nombre}_#{carpeta}.zip"
        ::DeleteTempFileJob.set(wait: 5.minutes).perform_later(tmp.path) rescue nil
      end

      def index
        set_patente_para_index
        fechas = @patente.fechas.order(fecha: :desc)
        render json: fechas.map { |fc| { id: fc.id, nombre_mostrado: fc.nombre_mostrado } }
      end

      private

      def set_patente_para_index
        @patente = FotosMelon::Patente.find(params[:patente_id])
      end
      def numerar(nombre, n)
        ext = File.extname(nombre)
        "#{File.basename(nombre, ext)} (#{n})#{ext}"
      end

      def set_patente
        @patente = FotosMelon::Patente.find(params[:patente_id])
      end

      def set_fecha
        @fecha = FotosMelon::FechaCarpeta.includes(:patente).find(params[:id])
      end

      def parsear_fecha(str)
        return nil if str.blank?
        s = str.to_s.strip
        if s =~ %r{\A(\d{4})-(\d{2})-(\d{2})\z}
          Date.new($1.to_i, $2.to_i, $3.to_i)
        elsif s =~ %r{\A(\d{2})/(\d{2})/(\d{4})\z}
          Date.new($3.to_i, $2.to_i, $1.to_i)
        else
          Date.parse(s)
        end
      rescue ArgumentError
        nil
      end
    end
  end
end