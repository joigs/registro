class MobilityAdjustment < ApplicationRecord
  validates :empresa, :fecha, presence: true
  validates :uf, numericality: true
  validates :servicios, numericality: { only_integer: true }
  scope :in_month, ->(y,m){ where(fecha: Date.new(y,m,1)..Date.civil(y,m,-1)) }
  scope :in_year,  ->(y,upto_m=12){ where(fecha: Date.new(y,1,1)..Date.civil(y,upto_m,-1)) }
end
