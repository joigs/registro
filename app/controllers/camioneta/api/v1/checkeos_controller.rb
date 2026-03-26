module Camioneta
  module Api
    module V1
      class CheckeosController < ApplicationController
        before_action :require_login
        before_action :set_checkeo, only: [
          :show,
          :update,
          :solicitar_eliminacion,
          :cancelar_eliminacion,
          :reportar_error,
          :responder_eliminacion
        ]

        def index
          checkeos = Camioneta::CheckCheckeo
                       .includes(:check_usuarios, :check_patente, :check_checkeo_usuarios)
                       .order(created_at: :desc)

          render json: checkeos.map { |checkeo| serialized_checkeo(checkeo) }, status: :ok
        end

        def show
          render json: serialized_checkeo(@checkeo), status: :ok
        end

        def create
          patente_codigo = params.dig(:checkeo, :patente_codigo)
          patente = Camioneta::CheckPatente.find_or_create_by!(codigo: patente_codigo)

          checkeo = Camioneta::CheckCheckeo.new(checkeo_params)
          checkeo.check_patente_id = patente.id

          usuario_ids = Array(params[:usuario_ids]).map(&:to_i).uniq
          usuario_ids << @current_usuario.id unless usuario_ids.include?(@current_usuario.id)

          if usuario_ids.empty?
            return render json: { error: "Debes asociar al menos un usuario" }, status: :unprocessable_entity
          end

          checkeo.completado = checkeo.campos_obligatorios_completos?

          if checkeo.save
            usuario_ids.each do |u_id|
              Camioneta::CheckCheckeoUsuario.create!(
                check_usuario_id: u_id,
                check_checkeo_id: checkeo.id,
                estado_eliminacion: :sin_solicitud
              )

              if u_id != @current_usuario.id
                enviar_notificacion(
                  u_id,
                  1,
                  "#{@current_usuario.nombre} te ha invitado a inspeccionar la patente #{patente.codigo} (Fecha: #{checkeo.fecha_chequeo})."
                )
              end
            end

            render json: serialized_checkeo(checkeo), status: :created
          else
            mensaje = checkeo.errors.full_messages.join(", ")
            if mensaje.downcase.include?("taken") || mensaje.downcase.include?("ya está")
              mensaje = "Ya existe una inspección para esta patente en el día de hoy."
            end

            render json: { error: mensaje }, status: :unprocessable_entity
          end
        end

        def update
          return render_forbidden unless @checkeo.asociado?(@current_usuario)

          @checkeo.assign_attributes(checkeo_params)
          @checkeo.completado = @checkeo.campos_obligatorios_completos?

          if @checkeo.save
            broadcast_checkeo_sync(@checkeo)
            render json: serialized_checkeo(@checkeo), status: :ok
          else
            render json: { errors: @checkeo.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def solicitar_eliminacion
          return render_forbidden unless @checkeo.asociado?(@current_usuario)

          relacion_actual = @checkeo.check_checkeo_usuarios.find_by!(check_usuario_id: @current_usuario.id)
          relacion_actual.update!(estado_eliminacion: :aprueba_eliminar)

          if @checkeo.listos_para_eliminar?
            broadcast_checkeo_eliminado(@checkeo)

            Camioneta::CheckLogOculto.create!(
              usuario_id_accion: @current_usuario.id,
              usuario_nombre: @current_usuario.nombre,
              accion_realizada: "Eliminación de Chequeo Aprobada",
              patente_afectada: @checkeo.check_patente.codigo
            )

            @checkeo.destroy!
            return render json: { deleted: true }, status: :ok
          end

          @checkeo.check_checkeo_usuarios.where.not(check_usuario_id: @current_usuario.id).find_each do |relacion|
            enviar_notificacion(
              relacion.check_usuario_id,
              2,
              "#{@current_usuario.nombre} solicita eliminar la inspección de la patente #{@checkeo.check_patente.codigo} (Fecha: #{@checkeo.fecha_chequeo})."
            )
          end

          broadcast_eliminacion_estado(@checkeo)

          render json: eliminacion_payload(@checkeo).merge(deleted: false), status: :ok
        end

        def cancelar_eliminacion
          return render_forbidden unless @checkeo.asociado?(@current_usuario)

          relacion_actual = @checkeo.check_checkeo_usuarios.find_by!(check_usuario_id: @current_usuario.id)
          relacion_actual.update!(estado_eliminacion: :sin_solicitud)

          @checkeo.check_checkeo_usuarios.where.not(check_usuario_id: @current_usuario.id).find_each do |relacion|
            enviar_notificacion(
              relacion.check_usuario_id,
              2,
              "#{@current_usuario.nombre} ha cancelado su solicitud para eliminar la inspección de la patente #{@checkeo.check_patente.codigo} (Fecha: #{@checkeo.fecha_chequeo})."
            )
          end

          broadcast_eliminacion_estado(@checkeo)

          render json: eliminacion_payload(@checkeo), status: :ok
        end

        def responder_eliminacion
          return render_forbidden unless @checkeo.asociado?(@current_usuario)

          aprueba = ActiveModel::Type::Boolean.new.cast(params[:aprueba])

          relacion = @checkeo.check_checkeo_usuarios.find_by!(check_usuario_id: @current_usuario.id)
          relacion.update!(estado_eliminacion: aprueba ? :aprueba_eliminar : :rechaza_eliminar)

          if @checkeo.listos_para_eliminar?
            broadcast_checkeo_eliminado(@checkeo)

            Camioneta::CheckLogOculto.create!(
              usuario_id_accion: @current_usuario.id,
              usuario_nombre: @current_usuario.nombre,
              accion_realizada: "Eliminación de Chequeo Aprobada",
              patente_afectada: @checkeo.check_patente.codigo
            )

            @checkeo.destroy!
            render json: { status: "eliminado" }, status: :ok
          else
            broadcast_eliminacion_estado(@checkeo)
            render json: eliminacion_payload(@checkeo).merge(status: "pendiente"), status: :ok
          end
        end

        def reportar_error
          return render_forbidden unless @checkeo.asociado?(@current_usuario)

          @checkeo.check_usuarios.where.not(id: @current_usuario.id).find_each do |usuario|
            enviar_notificacion(
              usuario.id,
              0,
              "Error reportado por #{@current_usuario.nombre} en patente #{@checkeo.check_patente.codigo} (Fecha: #{@checkeo.fecha_chequeo}): #{params[:mensaje]}"
            )
          end

          render json: { success: true }, status: :ok
        end

        private

        def set_checkeo
          @checkeo = Camioneta::CheckCheckeo
                       .includes(:check_usuarios, :check_patente, :check_checkeo_usuarios)
                       .find(params[:id])
        end

        def render_forbidden
          render json: { error: "No autorizado" }, status: :forbidden
        end

        def serialized_checkeo(checkeo)
          relacion = checkeo.check_checkeo_usuarios.find_by(check_usuario_id: @current_usuario.id)

          checkeo.as_json(
            include: [:check_usuarios, :check_patente],
            methods: [:conforme]
          ).merge(
            puede_editar: checkeo.asociado?(@current_usuario),
            estado_eliminacion_propio: relacion ? relacion[:estado_eliminacion] : 0,
            eliminacion_confirmados: checkeo.check_checkeo_usuarios.select(&:aprueba_eliminar?).count,
            eliminacion_total: checkeo.check_checkeo_usuarios.count
          )
        end

        def channel_snapshot(checkeo)
          checkeo.as_json(methods: [:conforme]).merge(
            eliminacion_confirmados: checkeo.check_checkeo_usuarios.select(&:aprueba_eliminar?).count,
            eliminacion_total: checkeo.check_checkeo_usuarios.count
          )
        end

        def eliminacion_payload(checkeo)
          {
            confirmados: checkeo.check_checkeo_usuarios.select(&:aprueba_eliminar?).count,
            total: checkeo.check_checkeo_usuarios.count
          }
        end

        def broadcast_checkeo_sync(checkeo)
          Camioneta::CheckeoChannel.broadcast_to(
            checkeo,
            {
              type: "checkeo_actualizado",
              data: channel_snapshot(checkeo)
            }
          )
        end

        def broadcast_eliminacion_estado(checkeo)
          Camioneta::CheckeoChannel.broadcast_to(
            checkeo,
            {
              type: "eliminacion_actualizada",
              confirmados: checkeo.check_checkeo_usuarios.select(&:aprueba_eliminar?).count,
              total: checkeo.check_checkeo_usuarios.count
            }
          )
        end

        def broadcast_checkeo_eliminado(checkeo)
          Camioneta::CheckeoChannel.broadcast_to(
            checkeo,
            {
              type: "checkeo_eliminado"
            }
          )
        end

        def checkeo_params
          params.require(:checkeo).permit(
            :check_patente_id,
            :fecha_chequeo,
            :completado,
            :corregido_fuera_de_fecha,
            :extintor,
            :kit_derrame,
            :botiquin,
            :gata,
            :cadenas,
            :llave_rueda,
            :antena_radio,
            :permiso_circulacion,
            :revision_tecnica,
            :soap,
            :alcohol,
            :protector_solar,
            :carpeta,
            :panos_limpieza,
            :conos,
            :radio_comunicacion,
            :espejo_inspeccion,
            :toldo,
            :pie_de_metro,
            :tintas,
            :arnes,
            :falta_diclofenaco_cant,
            :falta_guantes_cant,
            :falta_parche_curita_cant,
            :falta_gasa_cant,
            :falta_venda_cant,
            :falta_suero_cant,
            :falta_tela_adhesiva_cant,
            :falta_palitos_cant
          )
        end

        def enviar_notificacion(usuario_id, tipo, mensaje)
          Camioneta::CheckNotificacion.create!(
            check_usuario_id: usuario_id,
            tipo_notificacion: tipo,
            mensaje: mensaje
          )
        end
      end
    end
  end
end