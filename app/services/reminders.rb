# frozen_string_literal: true
class Reminders
  WINDOW_MOMENTS = %w[morning evening].freeze

  def self.tick!
    now = Time.zone.now
    today = Time.zone.today

    AppPauseWindow.where(enabled: true).find_each do |w|
      next unless WINDOW_MOMENTS.include?(w.moment)

      # dispara si coincide hora/minuto y no se envió hoy para ese momento
      should_fire = now.hour == w.hour && now.min == w.minute
      next unless should_fire

      already = AppReminder.where(fecha: today, moment: w.moment).where.not(sent_at: nil).exists?
      next if already

      trigger!(w.moment)
    end
  end

  # misma lógica que tu controller, concentrada aquí
  def self.trigger!(moment)
    raise ArgumentError, "moment inválido" unless WINDOW_MOMENTS.include?(moment)

    today = Time.zone.today
    now   = Time.zone.now

    
    #TODO: cambiar dependiendo de si los admin deben resibir una notificacion
    #users = AppUser.where(activo: true, creado: true).where.not(admin: true)
    users = AppUser.where(activo: true, creado: true)
    recipients = []

    users.find_each do |u|
      log = AppDailyLog.find_or_create_by!(app_user_id: u.id, fecha: today)
      needs = (moment == "morning") ? !log.morning_done : !log.evening_done
      next unless needs
      recipients << u
    end

    AppUser.where(id: recipients.map(&:id)).update_all(estado: false)

    recipients.each do |u|
      AppReminder.find_or_create_by!(app_user_id: u.id, fecha: today, moment: moment).tap do |r|
        r.update(sent_at: now)
        Notifier::Fcm.send_to(
          u,
          title: "Pausa activa",
          body: (moment == "morning" ? "¡Hora de la pausa de la mañana!" : "¡Hora de la pausa de la tarde!"),
          data: { screen: "PausaActiva", moment: moment }
        )
      end
    end

    { moment: moment, date: today, count: recipients.size }
  end
end
