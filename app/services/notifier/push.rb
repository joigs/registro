# frozen_string_literal: true
require "net/http"
require "uri"
require "json"

module Notifier
  class Push
    EXPO_URL = URI("https://exp.host/--/api/v2/push/send")
    TOKEN_RE  = /\AExponentPushToken\[[\w-]+\]\z/

    # Recibe un array de AppUser y envía en lotes.
    # data: hash con { screen: "PausaActiva", moment: "morning"|"evening" }
    def self.send_many(users, title:, body:, data: {})
      msgs = users.map do |u|
        next unless u.expo_push_token.present? && u.expo_push_token.match?(TOKEN_RE)
        {
          to: u.expo_push_token,
          title: title,
          body: body,
          data: data,
          sound: "default",
          priority: "high"
        }
      end.compact
      return { sent: 0, tickets: [] } if msgs.empty?

      tickets = []
      msgs.each_slice(100) do |slice|
        tickets += post_json(slice)
      end
      { sent: msgs.size, tickets: tickets }
    end

    def self.post_json(messages)
      http = Net::HTTP.new(EXPO_URL.host, EXPO_URL.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(EXPO_URL.request_uri, { "Content-Type" => "application/json" })
      req.body = messages.to_json
      res = http.request(req)
      if res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body).dig("data") || []
      else
        Rails.logger.warn("[Push] Expo error #{res.code}: #{res.body}")
        []
      end
    rescue => e
      Rails.logger.warn("[Push] Exception: #{e.class} #{e.message}")
      []
    end
  end
end
