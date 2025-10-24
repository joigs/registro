# frozen_string_literal: true
module Pausa
  module Reminders
    class Cron
      WINDOW_MINUTES = 5

      def self.tick(now = Time.zone.now)
        # Lunes(1)..Viernes(5)
        return unless (1..5).include?(now.wday)
        # Feriados
        return if Pausa::AppHoliday.exists?(fecha: now.to_date)

        wins = AppPauseWindow.where(enabled: true).index_by(&:moment) # "morning"/"evening"

        %w[morning evening].each do |moment|
          w = wins[moment]
          next unless w

          start = now.change(hour: w.hour, min: w.minute, sec: 0)
          finish = start + WINDOW_MINUTES.minutes

          if now >= start && now <= finish
            Rails.logger.info("[reminders] disparando #{moment} @ #{now}")
            Pausa::Reminders::Dispatcher.call(moment)
          end
        end
      end
    end
  end
end
