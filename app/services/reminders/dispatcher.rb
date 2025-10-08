# app/services/reminders/dispatcher.rb
class Reminders::Dispatcher
  def self.call(moment, now: Time.zone.now, today: Time.zone.today)
    raise ArgumentError, "moment inválido" unless %w[morning evening].include?(moment)

    users = AppUser.where(activo: true, creado: true).where.not(admin: true)
    recipients = []

    users.find_each do |u|
      log = AppDailyLog.find_or_create_by!(app_user_id: u.id, fecha: today)
      needs = (moment == "morning") ? !log.morning_done : !log.evening_done
      recipients << u if needs
    end

    AppUser.where(id: recipients.map(&:id)).update_all(estado: false)

    recipients.each do |u|
      AppReminder.find_or_create_by!(app_user_id: u.id, fecha: today, moment: moment).tap do |r|
        r.update(sent_at: now)
      end

      Notifier::Fcm.send_to(
        u,
        title: "Pausa activa",
        body: (moment == "morning" ? "¡Hora de la pausa de la mañana!" : "¡Hora de la pausa de la tarde!"),
        data: { screen: "PausaActiva", moment: moment }
      )
    end

    { moment: moment, date: today, count: recipients.size, ids: recipients.map(&:id) }
  end
end
