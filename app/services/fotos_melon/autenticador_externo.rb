module FotosMelon
  class AutenticadorExterno
    ERR_CREDENCIALES_INCOMPLETAS = "credenciales_incompletas".freeze
    ERR_USUARIO_NO_EXISTE        = "usuario_no_existe".freeze
    ERR_PASSWORD_INCORRECTO      = "password_incorrecto".freeze
    ERR_DB_EXTERNA               = "db_externa".freeze

    Resultado = Struct.new(:ok, :sec_user, :error, :codigo, keyword_init: true)

    def self.autenticar(mail:, password:)
      if mail.blank? || password.blank?
        return Resultado.new(
          ok: false,
          error: "Debes ingresar correo y contraseña",
          codigo: ERR_CREDENCIALES_INCOMPLETAS
        )
      end

      user = begin
               ::Midatech::SecUser.find_by("LOWER(SecUserMail) = ?", mail.to_s.downcase.strip)
             rescue StandardError => e
               Rails.logger.error("[FotosMelon::AutenticadorExterno] Error buscando usuario: #{e.class}: #{e.message}")
               return Resultado.new(
                 ok: false,
                 error: "No se pudo conectar con el servidor de usuarios. Intenta de nuevo en unos segundos.",
                 codigo: ERR_DB_EXTERNA
               )
             end

      unless user
        return Resultado.new(
          ok: false,
          error: "No existe ningún usuario con ese correo",
          codigo: ERR_USUARIO_NO_EXISTE
        )
      end

      unless user.authenticate_password(password)
        return Resultado.new(
          ok: false,
          error: "Contraseña incorrecta",
          codigo: ERR_PASSWORD_INCORRECTO
        )
      end

      Resultado.new(ok: true, sec_user: user)
    end

    def self.roles_validos_de(sec_user)
      roles = Array(sec_user.roles).map(&:to_s)
      roles.select { |r| [::Midatech::SecRole::ROL_ADMINISTRADOR, ::Midatech::SecRole::ROL_INSPECTOR].include?(r) }
    end

    def self.rol_interno_para(nombre_rol_externo)
      case nombre_rol_externo.to_s.downcase
      when "administrador" then Sesion::ROL_ADMINISTRADOR
      when "inspector"     then Sesion::ROL_INSPECTOR
      end
    end
  end
end