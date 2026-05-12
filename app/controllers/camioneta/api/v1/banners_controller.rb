module Camioneta
  module Api
    module V1
      class BannersController < ApplicationController
        before_action :require_login

        def index
          client_version = params[:version_cliente].to_i
          client_version = 1 if client_version < 1

          inline = Camioneta::AppBanner
                     .enabled
                     .inline_banners
                     .for_client_version(client_version)
                     .order(version: :desc, created_at: :desc)
                     .first

          modal = Camioneta::AppBanner
                    .enabled
                    .modal_banners
                    .for_client_version(client_version)
                    .order(version: :desc, created_at: :desc)
                    .first

          render json: {
            inline: inline ? serialize_banner(inline) : nil,
            modal: modal ? serialize_banner(modal) : nil
          }, status: :ok
        end

        private

        def serialize_banner(banner)
          {
            id: banner.id,
            kind: banner.kind,
            message: banner.message,
            link_url: banner.link_url,
            link_label: banner.link_label,
            enabled: banner.enabled,
            created_at: banner.created_at,
            version: banner.version
          }
        end
      end
    end
  end
end