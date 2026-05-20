module FotosMelon
  # Encapsula la lógica de login contra la base externa midatech.
  # Si el día de mañana las contraseñas se encriptan o si se cambia el origen
  # de los usuarios, solo este archivo y SecUser#authenticate_password cambian.
  class AutenticadorExterno
    Resultado = Struct.new(:ok, :sec_user, :error, keyword_init: true)

    def self.autenticar(mail:, password:)
      return Resultado.new(ok: false, error: "Credenciales incompletas") if mail.blank? || password.blank?

      user = ::Midatech::SecUser.find_by("LOWER(SecUserMail) = ?", mail.to_s.downcase.strip)
      return Resultado.new(ok: false, error: "Usuario o contraseña incorrectos") unless user
      return Resultado.new(ok: false, error: "Usuario o contraseña incorrectos") unless user.authenticate_password(password)

      Resultado.new(ok: true, sec_user: user)
    end

    # Devuelve los roles reales del usuario en la DB externa.
    # Si está vacío o ninguno coincide con Administrador/Inspector,
    # el controller decidirá qué hacer (en dev: permitir elegir manual).
    def self.roles_validos_de(sec_user)
      roles = Array(sec_user.roles).map(&:to_s)
      roles.select { |r| [::Midatech::SecRole::ROL_ADMINISTRADOR, ::Midatech::SecRole::ROL_INSPECTOR].include?(r) }
    end

    # Mapea el nombre del rol externo al rol interno normalizado.
    def self.rol_interno_para(nombre_rol_externo)
      case nombre_rol_externo.to_s.downcase
      when "administrador" then Sesion::ROL_ADMINISTRADOR
      when "inspector"     then Sesion::ROL_INSPECTOR
      end
    end
  end
end
