class ServiceWorkerController < ApplicationController
  protect_from_forgery except: :service_worker
  skip_before_action :protect_pages


  def service_worker

    end
  def manifest
    expires_now
    render template: "service_worker/manifest",
           formats: [:json],
           content_type: "application/manifest+json"
  end
end