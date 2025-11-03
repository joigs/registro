# app/controllers/pausa/api/v1/holidays_controller.rb
# frozen_string_literal: true

require "jwt"

module Pausa
  module Api
    module V1
      class HolidaysController < ApplicationController
        # Auth y filters igual que en AppUsersController
        before_action :authenticate!  # solo usuarios logueados
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # GET /pausa/api/v1/holidays/between?start=YYYY-MM-DD&end=YYYY-MM-DD
        def between
          begin_date = parse_date(params[:start])
          end_date   = parse_date(params[:end])
          return render json: { error: "Parámetros inválidos" }, status: :unprocessable_entity if begin_date.nil? || end_date.nil?

          days = Pausa::AppHoliday.where(fecha: begin_date..end_date).order(:fecha).pluck(:fecha)
          render json: days.map(&:to_s)
        end

        private

        def parse_date(s)
          return nil if s.blank?
          Date.iso8601(s) rescue nil
        end

        # ─── Auth helpers (mismo patrón que AppUsersController) ────────────────
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
      end
    end
  end
end
