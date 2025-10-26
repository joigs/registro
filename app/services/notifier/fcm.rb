# frozen_string_literal: true
require "googleauth"
require "faraday"
require "json"

module Notifier
  class Fcm
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    class << self
      # user: objeto con .expo_push_token
      # title, body: strings
      # data: hash extra (se envía dentro de data)
      def send_to(user, title:, body:, data: {})
        token = user&.expo_push_token.to_s.strip
        return false if token.empty?

        # Normalizamos el data: todo como string
        payload_data = stringify_values({ title: title.to_s, body: body.to_s }.merge(data || {}))

        payload = {
          message: {
            token: token,
            data: payload_data,
            android: {
              priority: "HIGH"
              # IMPORTANTE: sin 'notification' => data-only
            },
            apns: {
              # Para permitir data-only en iOS (background)
              headers: { "apns-priority" => "10" },
              payload: { aps: { "content-available" => 1 } }
            }
          }
        }

        post_fcm(payload)
      end

      private

      def post_fcm(payload)
        project_id = ENV.fetch("FCM_PROJECT_ID")
        conn = Faraday.new(url: "https://fcm.googleapis.com") do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.adapter Faraday.default_adapter
        end

        res = conn.post("/v1/projects/#{project_id}/messages:send") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"]  = "application/json; charset=utf-8"
          req.body = JSON.generate(payload)
        end

        unless res.success?
          Rails.logger.error("[FCM] error #{res.status} #{res.body}")
          return false
        end

        true
      end

      def access_token
        @token = nil if @token && @token.expires_at && Time.now >= (@token.expires_at - 60)
        @token ||= begin
                     authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
                       json_key_io: File.open(ENV.fetch("GOOGLE_APPLICATION_CREDENTIALS")),
                       scope: SCOPE
                     )
                     authorizer.fetch_access_token!
                     Struct.new(:token, :expires_at).new(authorizer.access_token, Time.now + 45 * 60)
                   end
        @token.token
      end

      def stringify_values(h)
        (h || {}).each_with_object({}) do |(k, v), acc|
          acc[k.to_s] =
            case v
            when String, Numeric, TrueClass, FalseClass
              v.to_s
            when NilClass
              ""
            else
              JSON.generate(v)
            end
        end
      end
    end
  end
end
