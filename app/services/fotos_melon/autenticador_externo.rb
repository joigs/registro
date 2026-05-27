module FotosMelon
  class AutenticadorExterno
    ERR_CREDENCIALES_INCOMPLETAS = "credenciales_incompletas".freeze
    ERR_USUARIO_NO_EXISTE        = "usuario_no_existe".freeze
    ERR_PASSWORD_INCORRECTO      = "password_incorrecto".freeze
    ERR_DB_EXTERNA               = "db_externa".freeze

    ROLES_PRIORIZADOS = [
      ::Midatech::SecRole::ROL_ADMINISTRADOR,
      ::Midatech::SecRole::ROL_INSPECTOR
    ].freeze

    Resultado = Struct.new(:ok, :sec_user, :error, :codigo, keyword_init: true)

    def self.autenticar(mail:, password:)
      if mail.blank? || password.blank?
        return Resultado.new(
          ok: false,
          error: "Debes ingresar correo y contraseña",
          codigo: ERR_CREDENCIALES_INCOMPLETAS
        )
      end

      candidatos = begin
                     ::Midatech::SecUser.where("LOWER(SecUserMail) = ?", mail.to_s.downcase.strip).to_a
                   rescue StandardError => e
                     Rails.logger.error("[FotosMelon::AutenticadorExterno] Error buscando usuarios: #{e.class}: #{e.message}")
                     return Resultado.new(
                       ok: false,
                       error: "No se pudo conectar con el servidor de usuarios. Intenta de nuevo en unos segundos.",
                       codigo: ERR_DB_EXTERNA
                     )
                   end

      if candidatos.empty?
        return Resultado.new(
          ok: false,
          error: "No existe ningún usuario con ese correo",
          codigo: ERR_USUARIO_NO_EXISTE
        )
      end

      ordenados = ordenar_por_prioridad(candidatos)

      ordenados.each do |user|
        begin
          return Resultado.new(ok: true, sec_user: user) if user.authenticate_password(password)
        rescue StandardError => e
          Rails.logger.error("[FotosMelon::AutenticadorExterno] Error validando password de user_id=#{user.id rescue 'n/a'}: #{e.class}: #{e.message}")
          next
        end
      end

      Resultado.new(
        ok: false,
        error: "Contraseña incorrecta",
        codigo: ERR_PASSWORD_INCORRECTO
      )
    end

    def self.ordenar_por_prioridad(usuarios)
      usuarios.sort_by.with_index do |user, idx|
        [prioridad_de(user), idx]
      end
    end

    def self.prioridad_de(user)
      roles = Array(user.roles).map(&:to_s)
      ROLES_PRIORIZADOS.each_with_index do |rol, i|
        return i if roles.include?(rol)
      end
      ROLES_PRIORIZADOS.length
    end

    def self.roles_validos_de(sec_user)
      roles = Array(sec_user.roles).map(&:to_s)
      roles.select { |r| ROLES_PRIORIZADOS.include?(r) }
    end

    def self.rol_interno_para(nombre_rol_externo)
      case nombre_rol_externo.to_s.downcase
      when "administrador" then Sesion::ROL_ADMINISTRADOR
      when "inspector"     then Sesion::ROL_INSPECTOR
      end
    end
  end
end
