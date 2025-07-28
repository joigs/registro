# frozen_string_literal: true

module Pausa
  class ServiceWorkerController < ActionController::Base
    protect_from_forgery except: :service_worker

    def manifest
      expires_now
      render template: "pausa/service_worker/manifest",
             formats:  [:json],
             layout:    false,
             content_type: "application/manifest+json"
    end

    def service_worker
      expires_now
      response.headers["Service-Worker-Allowed"] = "/ventas/pausa/"
      render template: "pausa/service_worker/service_worker",
             formats:  [:js],
             layout:    false,
             content_type: "application/javascript"
    end
  end
end
