module Camioneta
  module Api
    module V1
      class CheckeosController < ApplicationController
        before_action :require_login

        def index
          checkeos = Camioneta::CheckCheckeo.includes(:check_usuarios, :check_patente).order(created_at: :desc)
          render json: checkeos.as_json(include: [:check_usuarios, :check_patente]), status: :ok
        end

        def show
          checkeo = Camioneta::CheckCheckeo.find(params[:id])
          relacion = checkeo.check_checkeo_usuarios.find_by(check_usuario_id: @current_usuario.id)
          estado_elim = relacion ? relacion.estado_eliminacion : 0

          render json: checkeo.as_json(include: [:check_usuarios, :check_patente]).merge(estado_eliminacion_propio: estado_elim), status: :ok
        end


        def create
          patente_codigo = params.dig(:checkeo, :patente_codigo)
          patente = Camioneta::CheckPatente.find_or_create_by!(codigo: patente_codigo)

          checkeo = Camioneta::CheckCheckeo.new(checkeo_params)
          checkeo.check_patente_id = patente.id

          if checkeo.save
            params[:usuario_ids].each do |u_id|
              Camioneta::CheckCheckeoUsuario.create!(check_usuario_id: u_id, check_checkeo_id: checkeo.id, estado_eliminacion: 0)
              if u_id.to_i != @current_usuario.id
                enviar_notificacion(u_id, 1, "#{@current_usuario.nombre} te ha invitado a inspeccionar la patente #{patente.codigo} (Fecha: #{checkeo.fecha_chequeo}).")
              end
            end
            render json: checkeo, status: :created
          else
            mensaje = checkeo.errors.full_messages.join(", ")
            mensaje = "Ya existe una inspección para esta patente en el día de hoy." if mensaje.downcase.include?("taken") || mensaje.downcase.include?("ya está")
            render json: { error: mensaje }, status: :unprocessable_entity
          end
        end

        def solicitar_eliminacion
          checkeo = Camioneta::CheckCheckeo.find(params[:id])
          relacion_actual = checkeo.check_checkeo_usuarios.find_by(check_usuario_id: @current_usuario.id)
          relacion_actual.update(estado_eliminacion: 1)

          checkeo.check_checkeo_usuarios.where.not(check_usuario_id: @current_usuario.id).each do |relacion|
            enviar_notificacion(relacion.check_usuario_id, 2, "#{@current_usuario.nombre} solicita eliminar la inspección de la patente #{checkeo.check_patente.codigo} (Fecha: #{checkeo.fecha_chequeo}).")
          end

          render json: { success: true }, status: :ok
        end

        def cancelar_eliminacion
          checkeo = Camioneta::CheckCheckeo.find(params[:id])
          relacion_actual = checkeo.check_checkeo_usuarios.find_by(check_usuario_id: @current_usuario.id)
          relacion_actual.update(estado_eliminacion: 0)

          checkeo.check_checkeo_usuarios.where.not(check_usuario_id: @current_usuario.id).each do |relacion|
            enviar_notificacion(relacion.check_usuario_id, 2, "#{@current_usuario.nombre} ha cancelado su solicitud para eliminar la inspección de la patente #{checkeo.check_patente.codigo} (Fecha: #{checkeo.fecha_chequeo}).")
          end

          render json: { success: true }, status: :ok
        end

        def reportar_error
          checkeo = Camioneta::CheckCheckeo.find(params[:id])
          checkeo.check_usuarios.where.not(id: @current_usuario.id).each do |usuario|
            enviar_notificacion(usuario.id, 0, "Error reportado por #{@current_usuario.nombre} en patente #{checkeo.check_patente.codigo} (Fecha: #{checkeo.fecha_chequeo}): #{params[:mensaje]}")
          end
          render json: { success: true }, status: :ok
        end
        def update
          checkeo = CheckCheckeo.find(params[:id])
          if checkeo.update(checkeo_params)
            Camioneta::CheckeoChannel.broadcast_to(checkeo, checkeo.as_json)
            render json: checkeo, status: :ok
          else
            render json: { errors: checkeo.errors.full_messages }, status: :unprocessable_entity
          end
        end


        def responder_eliminacion
          checkeo = Camioneta::CheckCheckeo.find(params[:id])
          relacion = checkeo.check_checkeo_usuarios.find_by(check_usuario_id: @current_usuario.id)
          relacion.update(estado_eliminacion: params[:aprueba] ? 1 : 2)

          if checkeo.listos_para_eliminar?
            Camioneta::CheckLogOculto.create!(
              usuario_id_accion: @current_usuario.id,
              usuario_nombre: @current_usuario.nombre,
              accion_realizada: "Eliminacion de Chequeo Aprobada",
              patente_afectada: checkeo.check_patente.codigo
            )
            checkeo.destroy
            render json: { status: 'eliminado' }, status: :ok
          else
            render json: { status: 'pendiente' }, status: :ok
          end
        end



        private

        def checkeo_params
          params.require(:checkeo).permit(
            :check_patente_id, :fecha_chequeo, :completado, :corregido_fuera_de_fecha,
            :extintor, :kit_derrame, :botiquin, :gata, :cadenas, :llave_rueda,
            :antena_radio, :permiso_circulacion, :revision_tecnica, :soap, :alcohol,
            :protector_solar, :carpeta, :panos_limpieza, :conos, :radio_comunicacion,
            :espejo_inspeccion, :toldo, :pie_de_metro, :tintas, :arnes,
            :falta_diclofenaco_cant, :falta_guantes_cant, :falta_parche_curita_cant,
            :falta_gasa_cant, :falta_venda_cant, :falta_suero_cant,
            :falta_tela_adhesiva_cant, :falta_palitos_cant
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