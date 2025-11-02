# frozen_string_literal: true
module Pausa
  class AppBanner < ApplicationRecord
    self.table_name = "app_banners"

    KINDS = %w[inline modal].freeze

    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :message, presence: true
    validates :link_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

    scope :enabled,   -> { where(enabled: true) }
    scope :for_kind,  ->(k) { where(kind: k) }
    scope :for_admin, ->(is_admin) { is_admin ? all : where(admin_only: [false, nil]) }
  end
end


# Pausa::AppBanner.create!(
#   kind: "inline",
#   message: "hola.",
#   link_url: "https://url.cl/aviso",
#   link_label: "Ver aviso",
#   enabled: true,
#   admin_only: false
# )
#
# Pausa::AppBanner.create!(
#   kind: "modal",
#   message: "mensaje urgente.",
#   link_url: "https:url.com",
#   link_label: "Actualizar",
#   enabled: true,
#   admin_only: false
# )



