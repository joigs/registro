# app/controllers/pausa/api/v1/app_users_controller.rb
module Pausa
  module Api
    module V1
      class AppUsersController < ApplicationController
        before_action :authenticate!
        before_action :set_user, only: %i[show update destroy approve]
        before_action :authorize_admin!, only: %i[index pending approve destroy]
        before_action :authorize_self_or_admin!, only: %i[show update]

        # POST /app_users  (registro)
        def create
          user = AppUser.new(user_params)
          if user.save
            render json: user, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # GET /app_users           (admin) lista completa
        # GET /app_users/pending   (admin) sólo creados=false
        def index
          users = AppUser.all
          render json: users
        end

        def pending
          render json: AppUser.where(creado: false)
        end

        # GET /app_users/:id       (self o admin)
        def show
          render json: @user
        end

        # PATCH /app_users/:id     (self o admin)
        def update
          if @user.update(user_params.slice(:nombre, :correo))
            render json: @user
          else
            render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH /app_users/:id/approve   (admin)
        def approve
          @user.update(creado: true)
          head :no_content
        end

        # DELETE /app_users/:id    (admin)
        def destroy
          @user.destroy
          head :no_content
        end

        private

        # ─── Helpers ───────────────────────────────────────────────────
        def set_user
          @user = AppUser.find(params[:id])
        end

        def user_params
          params.require(:app_user).permit(:nombre, :rut, :correo)
        end

        # ─── Autenticación JWT sencilla ───────────────────────────────
        def authenticate!
          header = request.headers["Authorization"]
          return render(json: { error: "Falta token" }, status: :unauthorized) unless header&.start_with?("Bearer ")

          token = header.split(" ").last
          payload = JWT.decode(token, Rails.application.credentials.jwt_secret).first
          @current_user = AppUser.find(payload["id"])
        rescue StandardError
          render json: { error: "Token inválido" }, status: :unauthorized
        end

        def authorize_admin!
          render json: { error: "Solo admin" }, status: :forbidden unless @current_user.admin
        end

        def authorize_self_or_admin!
          return if @current_user.admin || @current_user.id == @user.id

          render json: { error: "No autorizado" }, status: :forbidden
        end
      end
    end
  end
end
