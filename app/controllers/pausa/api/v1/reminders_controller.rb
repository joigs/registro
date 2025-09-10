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
          moment = params[:moment].to_s
          unless %w[morning evening].include?(moment)
            return render json: { error: "moment inválido" }, status: :unprocessable_entity
          end

          today = Time.zone.today
          now   = Time.zone.now

          users = AppUser.where(activo: true, creado: true).where.not(admin: true)

          recipients = []
          users.find_each do |u|
            log = AppDailyLog.find_or_create_by!(app_user_id: u.id, fecha: today)
            needs = (moment == "morning") ? !log.morning_done : !log.evening_done
            next unless needs

            recipients << u
          end

          AppUser.where(id: recipients.map(&:id)).update_all(estado: false)

          reminders = []
          recipients.each do |u|
            reminders << AppReminder.find_or_create_by!(app_user_id: u.id, fecha: today, moment: moment).tap do |r|
              r.update(sent_at: now)
              Notifier::Push.send_to(
                u,
                title: "Pausa activa",
                body: (moment == "morning" ? "¡Hora de la pausa de la mañana!" : "¡Hora de la pausa de la tarde!"),
                data: { screen: "PausaActiva", moment: moment }
              )
            end
          end

          render json: {
            moment: moment,
            date: today,
            sent_to: recipients.map { |u| { id: u.id, nombre: u.nombre, rut: u.rut } },
            count: recipients.size
          }
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
