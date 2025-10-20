# frozen_string_literal: true
require "googleauth"
require "faraday"
require "json"

module Notifier
  class Fcm
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    class << self
      def send_to(user, title:, body:, data: {})
        token = user.expo_push_token.to_s.strip
        return false if token.empty?

        payload = {
          message: {
            token: token,
            android: {
              priority: "high",
              notification: {
                title: title,
                body: body,
                channel_id: "pausas"
              },
              data: stringify_keys(data)
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
          req.headers["Content-Type"]  = "application/json"
          req.body = JSON.generate(payload)
        end

        res.success?
      end

      def access_token
        @token = nil if @token && @token.expires_at && Time.now >= @token.expires_at - 60
        @token ||= begin
                     authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
                       json_key_io: File.open(ENV.fetch("GOOGLE_APPLICATION_CREDENTIALS")),
                       scope: SCOPE
                     )
                     authorizer.fetch_access_token!
                     Struct.new(:token, :expires_at).new(authorizer.access_token, Time.now + 45.minutes)
                   end
        @token.token
      end

      def stringify_keys(h)
        (h || {}).each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
      end
    end
  end
end
