module Camioneta
  class CheckeoChannel < ApplicationCable::Channel
    def subscribed
      @checkeo = Camioneta::CheckCheckeo.includes(:check_checkeo_usuarios).find_by(id: params[:checkeo_id])

      reject and return unless @checkeo
      reject and return unless autorizado?(@checkeo)

      stream_for @checkeo
    end

    def unsubscribed
    end


    def update_fields(data)
      return unless @checkeo
      return unless autorizado?(@checkeo)

      cambios = filtrar_cambios(data["changes"] || {})
      return if cambios.empty?

      if @checkeo.update(cambios)
        payload = {
          type: "checkeo_updated",
          checkeo_id: @checkeo.id,
          changes: @checkeo.saved_changes.slice(*cambios.keys.map(&:to_s)),
          updated_at: @checkeo.updated_at,
          updated_by_id: current_usuario.id,
          client_id: data["client_id"]
        }

        Camioneta::CheckeoChannel.broadcast_to(@checkeo, payload)
      else
        transmit({
                   type: "error",
                   errors: @checkeo.errors.full_messages
                 })
      end
    end

    private

    def autorizado?(checkeo)
      checkeo.check_checkeo_usuarios.exists?(check_usuario_id: current_usuario.id)
    end

    def filtrar_cambios(changes)
      permitted_keys = %w[
        fecha_chequeo completado corregido_fuera_de_fecha
        extintor kit_derrame botiquin gata cadenas llave_rueda
        antena_radio permiso_circulacion revision_tecnica soap alcohol
        protector_solar carpeta panos_limpieza conos radio_comunicacion
        espejo_inspeccion toldo pie_de_metro tintas arnes
        falta_diclofenaco_cant falta_guantes_cant falta_parche_curita_cant
        falta_gasa_cant falta_venda_cant falta_suero_cant
        falta_tela_adhesiva_cant falta_palitos_cant
      ]

      changes.slice(*permitted_keys)
    end
  end
end