module FotosMelon
  module Api
    module V1
      class FechasController < ApplicationController
        before_action :require_login
        before_action :require_admin, only: [:update, :destroy]
        before_action :set_patente, only: [:index, :create]
        before_action :set_fecha, only: [:show, :update, :destroy, :descargar]

        def index
          fechas = @patente.fechas.order(fecha: :desc)
          render json: fechas.map { |fc| serializar_fecha(fc) }
        end

        def show
          render json: serializar_fecha(@fecha, detalle: true)
        end

        def create
          fecha_dia = parsear_fecha(params[:fecha])
          unless fecha_dia
            return render json: { error: "Fecha inválida (usa dd/mm/yyyy o yyyy-mm-dd)" },
                          status: :unprocessable_entity
          end

          fc = @patente.fechas.create!(
            fecha: fecha_dia,
            creado_por_id: @current_user_id,
            creado_por_nombre: @current_user_name
          )
          render json: serializar_fecha(fc), status: :created
        rescue ActiveRecord::RecordNotUnique
          render json: { error: "Ya existe una carpeta para esa fecha" }, status: :unprocessable_entity
        end

        def update
          confirmacion = params[:confirmacion_nombre].to_s.strip
          if confirmacion != @fecha.nombre_mostrado.to_s.strip
            return render json: { error: "Confirmación inválida" }, status: :unprocessable_entity
          end

          @fecha.update!(nombre_personalizado: params[:nombre_personalizado])
          render json: serializar_fecha(@fecha)
        end

        def destroy
          confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
          if confirmacion != @fecha.patente.nombre
            return render json: { error: "Debes escribir la patente para confirmar" },
                          status: :unprocessable_entity
          end

          @fecha.fotos.find_each(batch_size: 50) do |foto|
            foto.imagen.purge_later if foto.imagen.attached?
          end
          @fecha.destroy!
          head :no_content
        end

        def descargar
          fotos = @fecha.fotos.includes(imagen_attachment: :blob).to_a
          attached = fotos.select { |f| f.imagen.attached? }

          if attached.empty?
            return render json: { error: "Carpeta vacía" }, status: :not_found
          end

          require "zip"
          tmpfile = Tempfile.new(["carpeta_", ".zip"], binmode: true)
          tmpfile.close

          nombres_usados = Hash.new(0)
          service = ActiveStorage::Blob.service

          ::Zip::File.open(tmpfile.path, Zip::File::CREATE) do |zip|
            attached.each do |foto|
              blob = foto.imagen.blob
              ruta = service.path_for(blob.key)
              next unless File.exist?(ruta)

              base = foto.nombre_descarga
              nombres_usados[base] += 1
              final = nombres_usados[base] == 1 ? base : numerar(base, nombres_usados[base])
              zip.add(final, ruta)
            end
          end

          carpeta = @fecha.nombre_personalizado.presence || @fecha.fecha.strftime("%d-%m-%Y")
          filename = "#{@fecha.patente.nombre}_#{carpeta}.zip"

          send_file tmpfile.path,
                    type: "application/zip",
                    disposition: "attachment",
                    filename: filename

          path_para_borrar = tmpfile.path
          ::DeleteTempFileJob.set(wait: 5.minutes).perform_later(path_para_borrar) rescue nil
        end

        private

        def set_patente
          @patente = FotosMelon::Patente.find(params[:patente_id])
        end

        def set_fecha
          @fecha = FotosMelon::FechaCarpeta.includes(:patente).find(params[:id])
        end

        def numerar(nombre, n)
          ext = File.extname(nombre)
          base = File.basename(nombre, ext)
          "#{base} (#{n})#{ext}"
        end

        def serializar_fecha(fc, detalle: false)
          base = {
            id: fc.id,
            patente_id: fc.patente_id,
            patente_nombre: fc.patente.nombre,
            fecha: fmt_fecha(fc.fecha),
            nombre_personalizado: fc.nombre_personalizado,
            nombre_mostrado: fc.nombre_mostrado,
            creado_por: { id: fc.creado_por_id, nombre: fc.creado_por_nombre },
            creado_en: fmt_fecha(fc.created_at),
            cantidad_fotos: fc.fotos.size
          }
          if detalle
            fotos_completas = fc.fotos.includes(imagen_attachment: :blob).order(:created_at)
            base[:fotos] = fotos_completas.map { |foto| serializar_foto(foto) }
          end
          base
        end

        def parsear_fecha(str)
          return nil if str.blank?
          s = str.to_s.strip
          if s =~ %r{\A(\d{2})/(\d{2})/(\d{4})\z}
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
end