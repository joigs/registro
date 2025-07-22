class ServiceWorkerController < ActionController::Base
  protect_from_forgery except: :service_worker

  def service_worker
    expires_now
    response.headers['Service-Worker-Allowed'] = '/ventas/'
    render template: "service_worker/service_worker",
           formats: [:js],
           content_type: "application/javascript"
  end

  def manifest
    expires_now
    render template: "service_worker/manifest",
           formats: [:json],
           content_type: "application/manifest+json"
  end
end
