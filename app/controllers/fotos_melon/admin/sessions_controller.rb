module FotosMelon
  module Admin
    class SessionsController < ::ApplicationController
      include FotosMelon::AdminAuthentication

      layout "fotos_melon/admin/auth"

      def new
        if current_sesion&.administrador?
          redirect_to fotos_melon_admin_root_path and return
        end
        @form = LoginForm.new
      end

      def create
        @form = LoginForm.new(login_params)
        mail = @form.mail.to_s
        password = @form.password.to_s

        resultado = FotosMelon::AutenticadorExterno.autenticar(mail: mail, password: password)

        unless resultado.ok
          flash.now[:alert] = mensaje_login(resultado.codigo, resultado.error)
          render :new, status: :unauthorized and return
        end

        sec_user       = resultado.sec_user
        roles_externos = FotosMelon::AutenticadorExterno.roles_validos_de(sec_user)

        tiene_admin = roles_externos.any? { |r| r.to_s.casecmp("administrador").zero? }

        unless tiene_admin
          flash.now[:alert] = "Solo administradores pueden acceder al panel web."
          render :new, status: :forbidden and return
        end

        sesion = FotosMelon::Sesion.create!(
          sec_user_id:   sec_user.SecUserId,
          sec_user_mail: sec_user.SecUserMail,
          sec_user_name: sec_user.SecUserName,
          rol:           FotosMelon::Sesion::ROL_ADMINISTRADOR
        )

        iniciar_sesion(sesion)
        redirect_to fotos_melon_admin_root_path, notice: "Bienvenido, #{sesion.sec_user_name}."
      end

      def destroy
        cerrar_sesion_actual
        redirect_to fotos_melon_admin_login_path, notice: "Sesión cerrada."
      end

      private

      def login_params
        params.require(:login_form).permit(:mail, :password)
      end

      def mensaje_login(codigo, mensaje_default)
        case codigo
        when FotosMelon::AutenticadorExterno::ERR_CREDENCIALES_INCOMPLETAS
          "Debes ingresar correo y contraseña."
        when FotosMelon::AutenticadorExterno::ERR_USUARIO_NO_EXISTE
          "No existe ningún usuario con ese correo."
        when FotosMelon::AutenticadorExterno::ERR_PASSWORD_INCORRECTO
          "Contraseña incorrecta."
        when FotosMelon::AutenticadorExterno::ERR_DB_EXTERNA
          "No se pudo verificar tu cuenta.."
        else
          mensaje_default.presence || "No se pudo iniciar sesión."
        end
      end

      class LoginForm
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :mail,     :string
        attribute :password, :string
      end
    end
  end
end