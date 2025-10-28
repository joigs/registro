module Pausa
  module Reminders
    class Cron
      WINDOW_MINUTES = 60  # ← antes 5

      def self.tick(now = Time.zone.now)
        return unless (1..5).include?(now.wday)
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
