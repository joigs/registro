# lib/tasks/reminders.rake
namespace :reminders do
  desc "Encola/envía recordatorios según el horario definido"
  task tick: :environment do
    now = Time.zone.now
    w = AppPauseWindow.where(enabled: true).to_a
    if w.any? { |x| x.moment == "morning" && now.hour == x.hour && now.min == x.minute }
      Reminders::Dispatcher.call("morning", now: now, today: now.to_date)
    end
    if w.any? { |x| x.moment == "evening" && now.hour == x.hour && now.min == x.minute }
      Reminders::Dispatcher.call("evening", now: now, today: now.to_date)
    end
  end
end
