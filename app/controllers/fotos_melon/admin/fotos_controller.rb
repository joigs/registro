module FotosMelon
  module Admin
    class FotosController < BaseController
      before_action :set_fecha, only: [:create]
      before_action :set_foto, only: [:update, :destroy, :ver, :descargar, :mover]

      def create
        archivos = Array(params[:imagenes]).reject(&:blank?)
        if archivos.empty?
          redirect_to fotos_melon_admin_fecha_path(@fecha), alert: "No seleccionaste fotos." and return
        end
        creadas = 0
        archivos.each do |archivo|
          next unless archivo.respond_to?(:original_filename)
          foto = @fecha.fotos.new(
            nombre: File.basename(archivo.original_filename, File.extname(archivo.original_filename)),
            subido_por_id: current_sesion.sec_user_id,
            subido_por_nombre: current_sesion.sec_user_name
          )
          foto.imagen.attach(io: archivo.tempfile, filename: archivo.original_filename, content_type: archivo.content_type)
          creadas += 1 if foto.save
        end
        redirect_to fotos_melon_admin_fecha_path(@fecha),
                    notice: "#{creadas} #{creadas == 1 ? 'foto subida' : 'fotos subidas'}."
      end

      def update
        @foto.update!(nombre: params.require(:nombre).to_s.strip)
        redirect_to fotos_melon_admin_fecha_path(@foto.fecha_carpeta_id), notice: "Foto renombrada."
      end

      def mover
        destino = FotosMelon::FechaCarpeta.find(params.require(:fecha_carpeta_id))
        origen = @foto.fecha_carpeta_id
        @foto.update!(fecha_carpeta: destino)
        redirect_to fotos_melon_admin_fecha_path(origen), notice: "Foto movida."
      end

      def destroy
        fecha = @foto.fecha_carpeta_id
        @foto.imagen.purge_later if @foto.imagen.attached?
        @foto.destroy!
        redirect_to fotos_melon_admin_fecha_path(fecha), notice: "Foto eliminada."
      end

      def ver
        return head(:not_found) unless @foto.imagen.attached?
        blob = @foto.imagen.blob
        ruta = ActiveStorage::Blob.service.path_for(blob.key)
        return head(:not_found) unless File.exist?(ruta)
        send_file ruta, type: blob.content_type.presence || "application/octet-stream",
                  disposition: "inline", filename: @foto.nombre_descarga
      end

      def descargar
        return head(:not_found) unless @foto.imagen.attached?
        blob = @foto.imagen.blob
        ruta = ActiveStorage::Blob.service.path_for(blob.key)
        return head(:not_found) unless File.exist?(ruta)
        send_file ruta, type: blob.content_type.presence || "application/octet-stream",
                  disposition: "attachment", filename: @foto.nombre_descarga
      end

      def descargar_zip
        ids = Array(params[:ids]).map(&:to_i).uniq.reject(&:zero?)
        fotos = FotosMelon::Foto.where(id: ids).includes(imagen_attachment: :blob).to_a.select { |f| f.imagen.attached? }
        if fotos.empty?
          redirect_back fallback_location: fotos_melon_admin_root_path, alert: "Sin fotos seleccionadas." and return
        end
        require "zip"
        tmp = Tempfile.new(["fotos_", ".zip"], binmode: true)
        tmp.close
        nombres = Hash.new(0)
        service = ActiveStorage::Blob.service
        ::Zip::File.open(tmp.path, Zip::File::CREATE) do |zip|
          fotos.each do |foto|
            ruta = service.path_for(foto.imagen.blob.key)
            next unless File.exist?(ruta)
            base = foto.nombre_descarga
            nombres[base] += 1
            final = nombres[base] == 1 ? base : "#{File.basename(base, File.extname(base))} (#{nombres[base]})#{File.extname(base)}"
            zip.add(final, ruta)
          end
        end
        send_file tmp.path, type: "application/zip", disposition: "attachment",
                  filename: "fotos_melon_#{Time.current.strftime('%Y%m%d_%H%M%S')}.zip"
        ::DeleteTempFileJob.set(wait: 5.minutes).perform_later(tmp.path) rescue nil
      end

      private

      def set_fecha
        @fecha = FotosMelon::FechaCarpeta.find(params[:fecha_id])
      end

      def set_foto
        @foto = FotosMelon::Foto.includes(:fecha_carpeta, imagen_attachment: :blob).find(params[:id])
      end
    end
  end
end