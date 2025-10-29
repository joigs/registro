class MobilityAdjustment < ApplicationRecord
  validates :empresa, :fecha, presence: true
  validates :uf, numericality: true
  validates :servicios, numericality: { only_integer: true }
  scope :in_month, ->(y,m){ where(fecha: Date.new(y,m,1)..Date.civil(y,m,-1)) }
  scope :in_year,  ->(y,upto_m=12){ where(fecha: Date.new(y,1,1)..Date.civil(y,upto_m,-1)) }
end






################## LOGS / EJEMPLOS ######################
#   MobilityAdjustment.create!(
#     empresa:         "Arauco",
#     mandante_rut:    "85805200",
#     mandante_nombre: "Forestal Arauco SA",
#     uf:              107.3,
#     servicios:       67,
#     fecha:           Date.new(2025, 10, 1)
#   )
#
#   MobilityAdjustment.create!(
#     empresa:         "Transporte de personal CMPC",
#     mandante_rut:    nil,
#     mandante_nombre: "Forestal Mininco SA",
#     uf:              34.2,
#     servicios:       26,
#     fecha:           Date.new(2025, 10, 1)
#   )