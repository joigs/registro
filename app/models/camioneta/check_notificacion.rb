module Camioneta
  class CheckNotificacion < ApplicationRecord
    self.table_name = "check_notificaciones"

    belongs_to :check_usuario, class_name: 'Camioneta::CheckUsuario'
    belongs_to :check_checkeo, class_name: 'Camioneta::CheckCheckeo', optional: true

    enum tipo_notificacion: {
      mensaje_error: 0,
      invitacion_chequeo: 1,
      solicitud_eliminacion: 2
    }

    after_create :limitar_a_50_por_tipo
    after_create :enviar_push_notification

    private

    def limitar_a_50_por_tipo
      notificaciones_activas = CheckNotificacion.where(
        check_usuario_id: check_usuario_id,
        tipo_notificacion: tipo_notificacion,
        leida: false
      ).order(created_at: :desc)

      if notificaciones_activas.count > 50
        ids_a_borrar = notificaciones_activas.offset(50).pluck(:id)
        CheckNotificacion.where(id: ids_a_borrar).destroy_all
      end
    end

    def enviar_push_notification
      return unless check_usuario&.push_token.present?

      begin
        Notifier::Fcm.send_notification(
          check_usuario.push_token,
          title: "Aviso de Inspección",
          body: self.mensaje
        )
      rescue => e
        Rails.logger.error("Error enviando FCM Push en Camioneta: #{e.message}")
      end
    end
  end
end