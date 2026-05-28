module FotosMelon
  module Admin
    class BaseController < ::ApplicationController
      skip_before_action :protect_pages, raise: false
      skip_before_action :set_current_user, raise: false

      include FotosMelon::AdminAuthentication

      layout "fotos_melon/admin/admin"

      before_action :require_admin_session

      rescue_from ActiveRecord::RecordNotFound, with: :no_encontrado

      private

      def no_encontrado
        respond_to do |format|
          format.html { redirect_to fotos_melon_admin_root_path, alert: "No encontrado" }
          format.any  { head :not_found }
        end
      end
    end
  end
end