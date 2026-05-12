module Camioneta
  class AppBanner < ApplicationRecord
    self.table_name = "camioneta_app_banners"

    KINDS = %w[inline modal].freeze

    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :message, presence: true
    validates :version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

    scope :enabled, -> { where(enabled: true) }
    scope :inline_banners, -> { where(kind: "inline") }
    scope :modal_banners, -> { where(kind: "modal") }

    scope :for_client_version, ->(client_version) {
      where("version >= ?", client_version.to_i)
    }





=begin
    # Inline para clientes versión <= 3
    Camioneta::AppBanner.create!(
      kind: "inline",
      message: "Hay una nueva versión disponible de la app.",
      link_url: "https://link.com/apk",
      link_label: "Descargar",
      enabled: true,
      version: 3
    )

    # Modal urgente para clientes versión <= 2
    Camioneta::AppBanner.create!(
      kind: "modal",
      message: "Versión obsoleta. Actualiza para seguir usando la app.",
      link_url: "https://link.com/apk",
      link_label: "Actualizar",
      enabled: true,
      version: 2
    )
=end


  end

end