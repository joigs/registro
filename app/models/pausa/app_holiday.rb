module Pausa
  class AppHoliday < ApplicationRecord
    self.table_name = "pausa_app_holidays"

    validates :fecha, presence: true, uniqueness: true
    scope :on, ->(date) { where(fecha: date) }
  end
end
