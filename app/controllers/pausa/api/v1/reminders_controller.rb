# frozen_string_literal: true
module Pausa
  module Api
    module V1
      class RemindersController < ApplicationController
        before_action :authenticate!
        before_action :authorize_admin!, only: [:trigger]
        skip_before_action :verify_authenticity_token
        skip_before_action :protect_pages

        # POST /reminders/trigger?moment=morning|evening
        def trigger
          today = Time.zone.today
          if weekend_or_holiday?(today)
            return render json: { skipped: true, reason: "no se envía en fines de semana ni feriados" }
          end

          moment = params[:moment].to_s
          result = Reminders::Dispatcher.call(moment)
          render json: result
        end

        # body: { moment: "morning"|"evening" }
        def opened
          moment = params[:moment].to_s
          return render(json: { error: "moment inválido" }, status: :unprocessable_entity) unless %w[morning evening].include?(moment)

          today = Time.zone.today
          r = AppReminder.find_by(app_user_id: @current_user.id, fecha: today, moment: moment)
          r&.update(opened_at: Time.zone.now)
          head :no_content
        end

        private

        def weekend_or_holiday?(date)
          return true if date.saturday? || date.sunday?
          return true if Pausa::AppHoliday.on(date).exists?
          false
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
