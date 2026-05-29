module FotosMelon
  module Api
    module V1
      class FotosController < ApplicationController
  

        before_action :require_login, except: [:descargar_zip_por_token]
        before_action :require_admin, only: [:update, :mover, :destroy]
        before_action :set_fecha, only: [:index, :create]
        before_action :set_foto, only: [:show, :update, :mover, :destroy, :descargar, :ver]

        def index
          fotos = @fecha.fotos.includes(imagen_attachment: :blob).order(:created_at)
          render json: fotos.map { |f| serializar_foto(f) }
        end

        def show
          render json: serializar_foto(@foto)
        end

        def create
          archivos = Array(params[:imagenes]).presence || Array(params[:imagen]).presence
          if archivos.blank?
            return render json: { error: "No se enviaron imágenes" }, status: :bad_request
          end

          creadas = []
          errores = []

          archivos.each do |archivo|
            next unless archivo.respond_to?(:original_filename)

            foto = @fecha.fotos.new(
              nombre: File.basename(archivo.original_filename, File.extname(archivo.original_filename)),
              subido_por_id: @current_user_id,
              subido_por_nombre: @current_user_name
            )
            foto.imagen.attach(
              io: archivo.tempfile,
              filename: archivo.original_filename,
              content_type: archivo.content_type
            )

            if foto.save
              creadas << serializar_foto(foto)
            else
              errores << { archivo: archivo.original_filename, error: foto.errors.full_messages.join(", ") }
            end

            archivo.tempfile.close rescue nil
          end

          GC.start if creadas.size > 5

          status = errores.empty? ? :created : :multi_status
          render json: { fotos: creadas, errores: errores }, status: status
        end

        def update
          @foto.update!(nombre: params.require(:nombre))
          render json: serializar_foto(@foto)
        end

        def mover
          destino = FotosMelon::FechaCarpeta.find(params.require(:fecha_carpeta_id))
          @foto.update!(fecha_carpeta: destino)
          render json: serializar_foto(@foto)
        end

        def destroy
          unless params[:confirmacion].to_s == "true"
            return render json: { error: "Confirmación requerida" }, status: :unprocessable_entity
          end
          @foto.imagen.purge_later if @foto.imagen.attached?
          @foto.destroy!
          head :no_content
        end

        def ver
          unless @foto.imagen.attached?
            return render json: { error: "Foto sin archivo" }, status: :not_found
          end

          blob = @foto.imagen.blob
          service = ActiveStorage::Blob.service
          ruta = service.path_for(blob.key)

          unless File.exist?(ruta)
            Rails.logger.error("[FotosMelon] Archivo no encontrado en disco: #{ruta}")
            return render json: { error: "Archivo no encontrado en disco" }, status: :not_found
          end

          send_file ruta,
                    type: blob.content_type.presence || "application/octet-stream",
                    disposition: "inline",
                    filename: @foto.nombre_descarga
        end

        # GET /fotos/:id/descargar — fuerza descarga con nombre correcto.
        def descargar
          unless @foto.imagen.attached?
            return render json: { error: "Foto sin archivo" }, status: :not_found
          end

          blob = @foto.imagen.blob
          service = ActiveStorage::Blob.service
          ruta = service.path_for(blob.key)

          unless File.exist?(ruta)
            return render json: { error: "Archivo no encontrado en disco" }, status: :not_found
          end

          send_file ruta,
                    type: blob.content_type.presence || "application/octet-stream",
                    disposition: "attachment",
                    filename: @foto.nombre_descarga
        end

        def preparar_zip
          ids = Array(params[:ids]).map(&:to_i).uniq.reject(&:zero?)
          if ids.empty?
            return render json: { error: "Sin fotos seleccionadas" }, status: :bad_request
          end

          existentes_count = FotosMelon::Foto.where(id: ids).count
          if existentes_count.zero?
            return render json: { error: "Las fotos no existen" }, status: :not_found
          end

          descarga = FotosMelon::Descarga.crear_para(
            sec_user_id: @current_user_id,
            ids: ids
          )

          FotosMelon::DeleteDescargaJob
            .set(wait: FotosMelon::Descarga::TTL + 1.minute)
            .perform_later(descarga.id)

          render json: {
            token: descarga.token,
            url: url_zip_por_token(descarga.token),
            expires_at: fmt_fecha_hora(descarga.expires_at),
            total_fotos: existentes_count
          }
        end

        def descargar_zip_por_token
          descarga = FotosMelon::Descarga.find_by(token: params[:token])
          unless descarga && descarga.vigente?
            return render json: { error: "Enlace inválido o expirado" }, status: :not_found
          end

          fotos = FotosMelon::Foto.where(id: descarga.ids)
                                  .includes(:fecha_carpeta, imagen_attachment: :blob)

          if fotos.empty?
            return render json: { error: "Sin fotos" }, status: :not_found
          end

          require "zip"
          tmpfile = Tempfile.new(["fotos_melon_", ".zip"], binmode: true)
          tmpfile.close  # rubyzip lo abrirá

          nombres_usados = Hash.new(0)
          service = ActiveStorage::Blob.service

          ::Zip::File.open(tmpfile.path, Zip::File::CREATE) do |zip|
            fotos.each do |foto|
              next unless foto.imagen.attached?
              blob = foto.imagen.blob
              ruta = service.path_for(blob.key)
              next unless File.exist?(ruta)

              base = foto.nombre_descarga
              nombres_usados[base] += 1
              final = nombres_usados[base] == 1 ? base : numerar(base, nombres_usados[base])

              zip.add(final, ruta)
            end
          end

          descarga.registrar_uso!

          filename = "fotos_melon_#{Time.current.strftime('%Y%m%d_%H%M%S')}.zip"
          send_file tmpfile.path,
                    type: "application/zip",
                    disposition: "attachment",
                    filename: filename
          path_para_borrar = tmpfile.path
          ::DeleteTempFileJob.set(wait: 5.minutes).perform_later(path_para_borrar) rescue nil
        end
        private

        def numerar(nombre, n)
          ext = File.extname(nombre)
          base = File.basename(nombre, ext)
          "#{base} (#{n})#{ext}"
        end

        def url_zip_por_token(token)
          "#{request.base_url}/ventas/fotos_melon/api/v1/fotos/zip/#{token}"
        end

        def set_fecha
          @fecha = FotosMelon::FechaCarpeta.find(params[:fecha_id])
        end

        def set_foto
          @foto = FotosMelon::Foto.includes(:fecha_carpeta, imagen_attachment: :blob).find(params[:id])
        end
      end
    end
  end
end
