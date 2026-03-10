module Camioneta
  class CheckeoChannel < ApplicationCable::Channel
    BOOLEAN_FIELDS = %w[
      botiquin gata cadenas llave_rueda antena_radio permiso_circulacion
      revision_tecnica soap alcohol protector_solar carpeta panos_limpieza
      conos radio_comunicacion espejo_inspeccion toldo pie_de_metro tintas arnes
    ].freeze

    INTEGER_FIELDS = %w[
      extintor kit_derrame
      falta_diclofenaco_cant falta_guantes_cant falta_parche_curita_cant
      falta_gasa_cant falta_venda_cant falta_suero_cant
      falta_tela_adhesiva_cant falta_palitos_cant
    ].freeze

    def subscribed
      @checkeo = Camioneta::CheckCheckeo
                   .includes(:check_checkeo_usuarios)
                   .find_by(id: params[:checkeo_id])

      reject and return unless @checkeo
      reject and return unless autorizado?

      stream_for @checkeo
    end

    def unsubscribed
    end

    # subscription.perform("update_fields", { changes: {...}, client_id: "abc123" })
    def update_fields(data)
      return unless @checkeo
      return unless autorizado?

      incoming = data["changes"].is_a?(Hash) ? data["changes"] : {}
      changes = sanitize_changes(incoming)
      return if changes.empty?

      if @checkeo.update(changes)
        Camioneta::CheckeoChannel.broadcast_to(
          @checkeo,
          {
            type: "checkeo_updated",
            checkeo_id: @checkeo.id,
            changes: changes,
            updated_at: @checkeo.updated_at.iso8601(3),
            updated_by_id: current_usuario.id,
            client_id: data["client_id"]
          }
        )
      else
        transmit(
          type: "error",
          errors: @checkeo.errors.full_messages
        )
      end
    end

    private

    def autorizado?
      @checkeo.check_checkeo_usuarios.exists?(check_usuario_id: current_usuario.id)
    end

    def sanitize_changes(incoming)
      allowed = BOOLEAN_FIELDS + INTEGER_FIELDS

      incoming.slice(*allowed).each_with_object({}) do |(key, value), acc|
        acc[key] =
          if BOOLEAN_FIELDS.include?(key)
            ActiveModel::Type::Boolean.new.cast(value)
          elsif value.nil? || value == ""
            nil
          else
            value.to_i
          end
      end
    end
  end
end