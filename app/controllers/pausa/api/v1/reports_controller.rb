# frozen_string_literal: true
require "csv"

module Pausa
  module Api
    module V1
      class ReportsController < ApplicationController
        # Acepta token por Header (Bearer) O por query ?auth=
        before_action :authenticate_header_or_query!
        before_action :authorize_admin!
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # GET /reports/pausas[.json|.csv|.pdf]?start=YYYY-MM-DD&end=YYYY-MM-DD
        # También soporta ?format=pdf|csv (por query) y ?auth=JWT
        def pausas
          start_date = params[:start].presence && Date.parse(params[:start])
          end_date   = params[:end].presence   && Date.parse(params[:end])
          return render(json: { error: "Faltan start y end" }, status: :unprocessable_entity) unless start_date && end_date

          logs = AppDailyLog
                   .includes(:app_user)
                   .where(fecha: start_date..end_date)
                   .order(:fecha, "app_users.rut")
                   .references(:app_user)

          # Resolver formato: extensión, Accept o query ?format=
          fmt = (params[:format].presence || request.format.symbol.to_s).to_s

          case fmt
          when "csv"
            send_data build_csv(logs),
                      filename: "reporte_pausas_#{start_date}_#{end_date}.csv",
                      type: "text/csv"
          when "pdf"
            windows = AppPauseWindow.all.index_by(&:moment)
            holidays = Pausa::AppHoliday.where(fecha: start_date..end_date).pluck(:fecha).to_set

            pdf = Pausa::Reports::PdfBuilder.build(
              start_date: start_date,
              end_date: end_date,
              logs: logs,
              users: AppUser.where(creado: true).order(:rut),
              windows: {
                morning: { h: windows["morning"]&.hour || 11, m: windows["morning"]&.minute || 0 },
                evening: { h: windows["evening"]&.hour || 16, m: windows["evening"]&.minute || 0 }
              },
              holidays: holidays
            )
            send_data pdf,
                      filename: "reporte_pausas_#{start_date}_#{end_date}.pdf",
                      type: "application/pdf"

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

        # --- Auth (Header o ?auth=) ---
        def jwt_secret
          Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"] || Rails.application.secret_key_base
        end

        def authenticate_header_or_query!
          header = request.headers["Authorization"]
          token =
            if header&.start_with?("Bearer ")
              header.split(" ").last
            elsif params[:auth].present?
              params[:auth].to_s
            end

          unless token
            render json: { error: "Falta token" }, status: :unauthorized and return
          end

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
