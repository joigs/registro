module FotosMelon
  module Api
    module V1
      class PatentesController < ApplicationController
        before_action :require_login
        before_action :require_admin, only: [:update, :destroy]
        before_action :set_patente, only: [:show, :update, :destroy, :descargar]

        def index
          q = FotosMelon::Patente.all
          q = q.where("LOWER(nombre) LIKE ?", "%#{params[:q].to_s.downcase}%") if params[:q].present?
          q = q.order(:nombre)

          render json: q.map { |p| serializar_patente(p) }
        end

        # GET /patentes/:id
        def show
          render json: serializar_patente(@patente, detalle: true)
        end

        def create
          patente = FotosMelon::Patente.new(
            nombre: params[:nombre],
            creado_por_id: @current_user_id,
            creado_por_nombre: @current_user_name
          )
          patente.save!
          render json: serializar_patente(patente), status: :created
        end

        def update
          confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
          if confirmacion != @patente.nombre
            return render json: { error: "Confirmación inválida" }, status: :unprocessable_entity
          end

          @patente.update!(nombre: params[:nombre])
          render json: serializar_patente(@patente)
        end

        def destroy
          confirmacion = params[:confirmacion_nombre].to_s.strip.upcase
          if confirmacion != @patente.nombre
            return render json: { error: "Confirmación inválida" }, status: :unprocessable_entity
          end

          FotosMelon::Foto.joins(:fecha_carpeta)
                          .where(fotos_melon_fechas: { patente_id: @patente.id })
                          .find_each(batch_size: 50) do |foto|
            foto.imagen.purge_later if foto.imagen.attached?
          end

          @patente.destroy!
          head :no_content
        end

        def descargar
          entries = []
          @patente.fechas.includes(fotos: { imagen_attachment: :blob }).each do |fc|
            carpeta = fc.nombre_personalizado.presence || fc.fecha.strftime("%d-%m-%Y")
            fc.fotos.each do |foto|
              next unless foto.imagen.attached?
              entries << {
                nombre_en_zip: "#{@patente.nombre}/#{carpeta}/#{foto.nombre_descarga}",
                blob: foto.imagen.blob
              }
            end
          end

          if entries.empty?
            return render json: { error: "No hay fotos para descargar" }, status: :not_found
          end

          stream_zip("#{@patente.nombre}.zip", entries)
        end

        private

        def set_patente
          @patente = FotosMelon::Patente.find(params[:id])
        end

        def serializar_patente(p, detalle: false)
          base = {
            id: p.id,
            nombre: p.nombre,
            creado_por: { id: p.creado_por_id, nombre: p.creado_por_nombre },
            creado_en: fmt_fecha(p.created_at),
            cantidad_fechas: p.fechas.size
          }
          if detalle
            base[:fechas] = p.fechas.order(fecha: :desc).map do |fc|
              {
                id: fc.id,
                fecha: fmt_fecha(fc.fecha),
                nombre_mostrado: fc.nombre_mostrado,
                cantidad_fotos: fc.fotos.size
              }
            end
          end
          base
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
