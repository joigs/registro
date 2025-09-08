module Pausa

  class AppPauseWindow < ApplicationRecord
    MOMENTS = %w[morning evening].freeze
    validates :moment, inclusion: { in: MOMENTS }, uniqueness: true #morning y evening
    validates :hour, inclusion: { in: 0..23 }
    validates :minute, inclusion: { in: 0..59 }





    def time_on(date)
      Time.zone.local(date.year, date.month, date.day, hour, minute)
    end
  end
end
