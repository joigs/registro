module FotosMelon
  module AdminAuthentication
    extend ActiveSupport::Concern

    COOKIE_KEY = :fotos_melon_admin_token

    included do
      helper_method :current_admin, :current_sesion if respond_to?(:helper_method)
    end

    private

    def require_admin_session
      unless current_sesion
        respond_to do |format|
          format.html { redirect_to fotos_melon_admin_login_path, alert: "Inicia sesión para continuar." }
          format.any  { head :unauthorized }
        end
        return
      end

      unless current_sesion.administrador?
        cerrar_sesion_actual
        respond_to do |format|
          format.html { redirect_to fotos_melon_admin_login_path, alert: "Solo administradores pueden acceder al panel web." }
          format.any  { head :forbidden }
        end
        return
      end

      current_sesion.tocar!
    end

    def current_sesion
      return @current_sesion if defined?(@current_sesion)

      token = cookies.signed[COOKIE_KEY]
      @current_sesion =
        if token.present?
          FotosMelon::Sesion.find_by(token: token)&.then { |s| s.vigente? ? s : nil }
        end
    end

    def current_admin
      current_sesion
    end

    def iniciar_sesion(sesion)
      cookies.signed[COOKIE_KEY] = {
        value: sesion.token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        expires: 6.months.from_now
      }
      @current_sesion = sesion
    end

    def cerrar_sesion_actual
      current_sesion&.cerrar! if current_sesion.respond_to?(:cerrar!)
      cookies.delete(COOKIE_KEY)
      @current_sesion = nil
    end
  end
end