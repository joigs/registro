module Pausa

  class AppReminder < ApplicationRecord

    self.table_name = "app_reminders"

      belongs_to :app_user, class_name: "Pausa::AppUser"

      validates :fecha, :moment, presence: true

      validates :moment, inclusion: { in: %w[morning evening] }
  end

end
