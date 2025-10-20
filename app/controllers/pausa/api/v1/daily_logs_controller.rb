# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class DailyLogsController < ApplicationController
        before_action :authenticate!
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # GET /daily_logs/today
        # Agregamos flags para que el cliente oculte botón en fds/feriado
        def today
          today = Time.zone.today
          locked, reason = weekend_or_holiday?(today)

          log = ensure_today_log(@current_user) # mantener para consistencia histórica
          render json: serialize_log(log).merge(locked: locked, reason: reason)
        end

        # PATCH /daily_logs/mark  (params: moment=morning|evening)
        def mark
          moment = params[:moment].to_s
          unless %w[morning evening].include?(moment)
            return render json: { error: "moment inválido" }, status: :unprocessable_entity
          end

          today = Time.zone.today
          locked, reason = weekend_or_holiday?(today)
          if locked
            # respuesta amigable; el cliente mostrará el texto, NO códigos crudos
            return render json: { error: (reason == "feriado" ? "Hoy es feriado. No se registran pausas." : "Fin de semana. No se registran pausas.") },
                          status: :unprocessable_entity
          end

          log = ensure_today_log(@current_user)
          now = Time.zone.now

          if moment == "morning"
            log.update(morning_done: true, morning_at: (log.morning_at || now))
          else
            log.update(evening_done: true, evening_at: (log.evening_at || now))
          end

          @current_user.update(estado: true) rescue nil

          render json: serialize_log(log)
        end

        private

        def weekend_or_holiday?(date)
          return [true, "fin_de_semana"] if date.saturday? || date.sunday?
          return [true, "feriado"]       if Pausa::AppHoliday.on(date).exists?
          [false, nil]
        end

        def ensure_today_log(user)
          today = Time.zone.today
          AppDailyLog.find_or_create_by!(app_user_id: user.id, fecha: today)
        end

        def serialize_log(log)
          {
            id: log.id,
            fecha: log.fecha,
            morning: { done: log.morning_done, at: log.morning_at },
            evening: { done: log.evening_done, at: log.evening_at }
          }
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
      end
    end
  end
end
