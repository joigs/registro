module FotosMelon
  class DeleteDescargaJob < ApplicationJob
    queue_as :default

    def perform(descarga_id)
      d = FotosMelon::Descarga.find_by(id: descarga_id)
      return unless d
      d.destroy
    rescue StandardError => e
      Rails.logger.warn("[FotosMelon::DeleteDescargaJob] #{e.class}: #{e.message}")
    end
  end
end
