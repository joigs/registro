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
          entries = @fecha.fotos.includes(imagen_attachment: :blob).filter_map do |foto|
            next unless foto.imagen.attached?
            { nombre_en_zip: foto.nombre_descarga, blob: foto.imagen.blob }
          end

          if entries.empty?
            return render json: { error: "Carpeta vacía" }, status: :not_found
          end

          carpeta = @fecha.nombre_personalizado.presence || @fecha.fecha.strftime("%d-%m-%Y")
          stream_zip("#{@fecha.patente.nombre}_#{carpeta}.zip", entries)
        end

        private

        def set_patente
          @patente = FotosMelon::Patente.find(params[:patente_id])
        end

        def set_fecha
          @fecha = FotosMelon::FechaCarpeta.includes(:patente).find(params[:id])
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
            base[:fotos] = fc.fotos.order(:created_at).map do |foto|
              {
                id: foto.id,
                nombre: foto.nombre,
                subido_por: { id: foto.subido_por_id, nombre: foto.subido_por_nombre },
                subido_en: fmt_fecha(foto.created_at),
                tamano: foto.tamano_bytes
              }
            end
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

        def stream_zip(filename, entries)
          response.headers["Content-Type"] = "application/zip"
          response.headers["Content-Disposition"] = %(attachment; filename="#{filename}")
          response.headers["X-Accel-Buffering"] = "no"
          response.headers["Cache-Control"] = "no-cache"
          FotosMelon::ZipStreamer.stream_to_io(entries, response.stream)
        ensure
          response.stream.close
        end
      end
    end
  end
end
