module Pausa
  class AppDailyLog < ApplicationRecord
    self.table_name = "app_daily_logs"

    belongs_to :app_user, class_name: "Pausa::AppUser"

    validates :date, presence: true
    validates :date, uniqueness: { scope: :app_user_id }

    def mark_morning!
      update!(morning_at: Time.current, morning_done: true)
    end

    def mark_evening!
      update!(evening_at: Time.current, evening_done: true)
    end
  end
end
