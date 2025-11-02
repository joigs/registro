# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class BannersController < ApplicationController
        before_action :authenticate!
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages
        def index
          is_admin = current_user&.admin? || false
          scoped   = Pausa::AppBanner.enabled.for_admin(is_admin)

          inline = scoped.for_kind("inline").order(created_at: :desc).limit(1).first
          modal  = scoped.for_kind("modal").order(created_at: :desc).limit(1).first

          render json: {
            inline: inline ? serialize(inline) : nil,
            modal:  modal  ? serialize(modal)  : nil
          }
        end

        private

        def serialize(b)
          {
            id: b.id,
            kind: b.kind,
            message: b.message,
            link_url: b.link_url,
            link_label: b.link_label,
            enabled: b.enabled,
            admin_only: b.admin_only,
            created_at: b.created_at
          }
        end
      end
    end
  end
end
