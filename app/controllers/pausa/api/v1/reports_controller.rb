# frozen_string_literal: true
require "csv"

module Pausa
  module Api
    module V1
      class ReportsController < ApplicationController
        before_action :authenticate!
        before_action :authorize_admin!
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # GET /reports/pausas?start=YYYY-MM-DD&end=YYYY-MM-DD&format=(json|csv)
        def pausas
          start_date = params[:start].presence && Date.parse(params[:start])
          end_date   = params[:end].presence   && Date.parse(params[:end])
          return render(json: { error: "Faltan start y end" }, status: :unprocessable_entity) unless start_date && end_date

          logs = AppDailyLog
                   .includes(:app_user)
                   .where(fecha: start_date..end_date)
                   .order(:fecha, "app_users.rut")
                   .references(:app_user)

          if params[:format] == "csv"
            send_data build_csv(logs),
                      filename: "reporte_pausas_#{start_date}_#{end_date}.csv",
                      type: "text/csv"
          else
            render json: logs.map { |l| serialize_log(l) }
          end
        end

        private

        def serialize_log(l)
          {
            fecha: l.fecha,
            user: { id: l.app_user_id, rut: l.app_user.rut, nombre: l.app_user.nombre, correo: l.app_user.correo },
            morning: { done: l.morning_done, at: l.morning_at },
            evening: { done: l.evening_done, at: l.evening_at }
          }
        end

        def build_csv(logs)
          CSV.generate(headers: true) do |csv|
            csv << %w[fecha user_id rut nombre correo moment realizado_at realizado]
            logs.each do |l|
              csv << [l.fecha, l.app_user_id, l.app_user.rut, l.app_user.nombre, l.app_user.correo, "morning", l.morning_at, l.morning_done]
              csv << [l.fecha, l.app_user_id, l.app_user.rut, l.app_user.nombre, l.app_user.correo, "evening", l.evening_at, l.evening_done]
            end
          end
        end

        # --- Auth helpers ---
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
