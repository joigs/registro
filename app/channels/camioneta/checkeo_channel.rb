module Camioneta
  class CheckeoChannel < ApplicationCable::Channel
    def subscribed
      @checkeo = Camioneta::CheckCheckeo.find_by(id: params[:checkeo_id])

      reject and return unless @checkeo
      reject and return unless @checkeo.asociado?(current_usuario)

      stream_for @checkeo
    end

    def unsubscribed
    end

    def actualizar_campo(data)
      return transmit({ type: "error", message: "Checkeo no encontrado" }) unless @checkeo
      return transmit({ type: "error", message: "No autorizado" }) unless @checkeo.asociado?(current_usuario)

      campo = data["campo"].to_s
      valor = data["valor"]

      unless Camioneta::CheckCheckeo::REALTIME_EDITABLE_FIELDS.include?(campo)
        return transmit({ type: "error", message: "Campo no permitido", campo: campo })
      end

      @checkeo.with_lock do
        @checkeo.apply_realtime_update!(campo, valor)
      end

      Camioneta::CheckeoChannel.broadcast_to(
        @checkeo,
        {
          type: "campo_actualizado",
          checkeo_id: @checkeo.id,
          campo: campo,
          valor: @checkeo.public_send(campo),
          completado: @checkeo.completado,
          conforme: @checkeo.conforme,
          updated_by: current_usuario.id
        }
      )
    rescue ActiveRecord::RecordInvalid => e
      transmit({ type: "error", message: e.record.errors.full_messages.to_sentence, campo: campo })
    rescue ArgumentError => e
      transmit({ type: "error", message: e.message, campo: campo })
    rescue => e
      transmit({ type: "error", message: "No se pudo guardar el cambio" })
      Rails.logger.error("[CheckeoChannel] #{e.class}: #{e.message}")
    end
  end
end