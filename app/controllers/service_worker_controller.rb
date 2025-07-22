# app/controllers/service_worker_controller.rb
class ServiceWorkerController < ActionController::Base
  skip_forgery_protection

  def manifest
    expires_in 1.hour, public: true
    render 'service-worker/manifest', formats: :json,
           content_type: 'application/manifest+json'
  end

  def service_worker
    response.headers['Service-Worker-Allowed'] = '/ventas/'
    expires_in 0, public: true
    render 'service-worker/service_worker', formats: :js,
           content_type: 'application/javascript'
  end
end
