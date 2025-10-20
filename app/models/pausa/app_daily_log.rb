# app/models/pausa/app_daily_log.rb
module Pausa
  class AppDailyLog < ApplicationRecord
    self.table_name = "app_daily_logs"

    belongs_to :app_user, class_name: "Pausa::AppUser"

    alias_attribute :date, :fecha

    validates :fecha, presence: true
    validates :fecha, uniqueness: { scope: :app_user_id }

    def mark_morning!
      update!(morning_at: Time.current, morning_done: true)
    end

    def mark_evening!
      update!(evening_at: Time.current, evening_done: true)
    end
  end
end
