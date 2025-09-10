# frozen_string_literal: true
module Notifier
  class Push
    def self.send_to(user, title:, body:, data: {})
      return :skipped unless user.expo_push_token.present?
      Rails.logger.info("[PUSH] to=#{user.id} token=#{user.expo_push_token} title=#{title} body=#{body} data=#{data.inspect}")
      :ok
    end
  end
end
