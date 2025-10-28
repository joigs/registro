# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :environment, :production
set :path, "/home/vertical/registro"
set :output, "/home/vertical/registro/log/cron.log"

env :PATH, "/home/vertical/.rbenv/shims:/home/vertical/.rbenv/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

env "GOOGLE_APPLICATION_CREDENTIALS", "/home/vertical/registro/config/firebase-sa.json"
env "FCM_PROJECT_ID", "pausaactiva-31704"

every '0-55/5 11 * * 1-5' do
  runner "Pausa::Reminders::Cron.tick"
end
# 16:00–16:55 cada 5 min (L–V)
every '0-55/5 16 * * 1-5' do
  runner "Pausa::Reminders::Cron.tick"
end