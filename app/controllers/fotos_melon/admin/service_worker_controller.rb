module FotosMelon
  module Admin
    class ServiceWorkerController < ActionController::Base
      protect_from_forgery except: [:service_worker]

      def service_worker
        expires_now
        response.headers["Service-Worker-Allowed"] = "/ventas/fotos_melon/admin/"
        render template: "fotos_melon/admin/service_worker/service_worker",
               formats: [:js],
               layout: false,
               content_type: "application/javascript"
      end

      def manifest
        expires_now
        render template: "fotos_melon/admin/service_worker/manifest",
               formats: [:json],
               layout: false,
               content_type: "application/manifest+json"
      end
    end
  end
end