# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class PauseWindowsController < ApplicationController
        before_action :authenticate!
        before_action :authorize_admin!, only: [:update]
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # GET /pause_windows
        def index
          now_iso = Time.current.iso8601
          response.set_header("X-Server-Time", now_iso)
          windows = AppPauseWindow.order(:moment)
          render json: windows.map { |w| w.as_json.merge(server_now: now_iso) }
        end

        # PATCH /pause_windows/:moment   (morning|evening)
        def update
          w = AppPauseWindow.find_by!(moment: params[:id])
          if w.update(window_params)
            render json: w
          else
            render json: { errors: w.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def window_params
          params.permit(:hour, :minute, :enabled)
        end

        # --- Auth helpers (igual que en AppUsersController) ---
        def jwt_secret
          Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"] || Rails.application.secret_key_base
        end

        def authenticate!
          header = request.headers["Authorization"]
          unless header&.start_with?("Bearer ")
            render json: { error: "Falta token" }, status: :unauthorized and return
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
          return if performed?
          render json: { error: "Solo admin" }, status: :forbidden unless @current_user&.admin
        end
      end
    end
  end
end
