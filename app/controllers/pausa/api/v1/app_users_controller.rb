# frozen_string_literal: true

require "jwt"

module Pausa
  module Api
    module V1
      class AppUsersController < ApplicationController
        # Auth
        before_action :authenticate!, except: [:create]  # registro público
        before_action :set_user, only: %i[show update destroy approve push_token]
        before_action :authorize_admin!, only: %i[index pending approve destroy set_active]
        before_action :authorize_self_or_admin!, only: %i[show update push_token]

        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # ---- CRUD / Flujos ----
        def create
          user = AppUser.new(user_params)
          if user.save
            render json: user, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def index
          render json: AppUser.all
        end

        def pending
          render json: AppUser.where(creado: false)
        end

        def show
          render json: @user
        end

        def update
          if @user.update(user_params.slice(:nombre, :correo))
            render json: @user
          else
            render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def approve
          @user.update(creado: true)
          head :no_content
        end

        def destroy
          @user.destroy
          head :no_content
        end

        def me
          render json: @current_user
        end


        def push_token
          token_param = params[:fcm_token].presence || params[:expo_push_token].presence
          return render(json: { error: "Falta fcm_token" }, status: :unprocessable_entity) if token_param.blank?

     
          AppUser.transaction do
            AppUser.where(expo_push_token: token_param)
                   .where.not(id: @user.id)
                   .update_all(expo_push_token: nil)

            @user.update!(expo_push_token: token_param)
          end

          head :no_content
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: Array(e.record&.errors&.full_messages).presence || ["No se pudo actualizar"] },
                 status: :unprocessable_entity
        end



        def set_active
          @user = AppUser.find(params[:id])
          value = ActiveModel::Type::Boolean.new.cast(params[:activo])
          @user.update!(activo: value)
          render json: { id: @user.id, activo: @user.activo }
        end


        private

        # ─── Helpers ───────────────────────────────────────────────────────────
        def set_user
          @user = AppUser.find(params[:id])
        end

        def user_params
          params.require(:app_user).permit(:nombre, :rut, :correo)
        end

        # ─── Auth ──────────────────────────────────────────────────────────────
        def jwt_secret
          Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"] || Rails.application.secret_key_base
        end

        def authenticate!
          header = request.headers["Authorization"]
          unless header&.start_with?("Bearer ")
            render json: { error: "Falta token" }, status: :unauthorized
            return
          end

          token = header.split(" ").last
          payload = JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
          @current_user = AppUser.find(payload["id"])
        rescue JWT::ExpiredSignature
          render json: { error: "Token expirado" }, status: :unauthorized
        rescue StandardError
          render json: { error: "Token inválido" }, status: :unauthorized
        end

        def authorize_admin!
          return if performed? # si authenticate! ya respondió, no sigas
          unless @current_user&.admin
            render json: { error: "Solo admin" }, status: :forbidden
          end
        end

        def authorize_self_or_admin!
          return if performed?
          return if @current_user&.admin || @current_user&.id == @user.id
          render json: { error: "No autorizado" }, status: :forbidden
        end
      end
    end
  end
end
