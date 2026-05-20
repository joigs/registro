module FotosMelon
  module Api
    module V1
      class SessionsController < ApplicationController
        before_action :require_login, only: [:destroy, :me]

        def create
          mail       = params[:mail].to_s
          password   = params[:password].to_s
          rol_manual = params[:rol_manual].to_s.downcase.presence

          resultado = FotosMelon::AutenticadorExterno.autenticar(mail: mail, password: password)
          unless resultado.ok
            return render json: { error: resultado.error }, status: :unauthorized
          end

          sec_user = resultado.sec_user
          roles_externos  = FotosMelon::AutenticadorExterno.roles_validos_de(sec_user)
          permitir_manual = ENV["FOTOS_MELON_PERMITIR_ROL_MANUAL"].to_s == "true"

          rol_elegido =
            if roles_externos.size == 1
              FotosMelon::AutenticadorExterno.rol_interno_para(roles_externos.first)
            elsif roles_externos.size > 1
              rol_interno_o_error(rol_manual, roles_externos)
            elsif permitir_manual
              rol_interno_o_error(rol_manual, ["Administrador", "Inspector"])
            else
              return render json: { error: "Usuario sin rol autorizado" }, status: :forbidden
            end

          return if performed?
          return render json: { error: "Rol inválido" }, status: :forbidden unless rol_elegido

          sesion = FotosMelon::Sesion.create!(
            sec_user_id:   sec_user.SecUserId,
            sec_user_mail: sec_user.SecUserMail,
            sec_user_name: sec_user.SecUserName,
            rol:           rol_elegido,
            )

          render json: {
            token: sesion.token,
            usuario: {
              id: sesion.sec_user_id,
              nombre: sesion.sec_user_name,
              mail: sesion.sec_user_mail,
              rol: sesion.rol
            },
            permitir_rol_manual: permitir_manual,
            roles_disponibles: roles_disponibles_para(sec_user, permitir_manual)
          }, status: :created
        end

        def me
          render json: {
            usuario: {
              id: @current_sesion.sec_user_id,
              nombre: @current_sesion.sec_user_name,
              mail: @current_sesion.sec_user_mail,
              rol: @current_sesion.rol
            }
          }
        end

        def destroy
          @current_sesion&.cerrar!
          head :no_content
        end

        def roles_disponibles
          mail = params[:mail].to_s
          password = params[:password].to_s
          resultado = FotosMelon::AutenticadorExterno.autenticar(mail: mail, password: password)
          unless resultado.ok
            return render json: { error: resultado.error }, status: :unauthorized
          end
          permitir_manual = ENV["FOTOS_MELON_PERMITIR_ROL_MANUAL"].to_s == "true"
          render json: { roles: roles_disponibles_para(resultado.sec_user, permitir_manual) }
        end

        private

        def rol_interno_o_error(rol_manual, roles_externos)
          unless rol_manual
            render json: {
              error: "Debes elegir un rol",
              roles_disponibles: roles_externos
            }, status: :unprocessable_entity
            return nil
          end

          permitidos = roles_externos.map { |r| FotosMelon::AutenticadorExterno.rol_interno_para(r) }.compact
          unless permitidos.include?(rol_manual)
            render json: {
              error: "Rol no permitido para este usuario",
              roles_disponibles: roles_externos
            }, status: :forbidden
            return nil
          end

          rol_manual
        end

        def roles_disponibles_para(sec_user, permitir_manual)
          externos = FotosMelon::AutenticadorExterno.roles_validos_de(sec_user)
          return externos if externos.any?
          permitir_manual ? ["Administrador", "Inspector"] : []
        end
      end
    end
  end
end