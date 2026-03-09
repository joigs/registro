module Camioneta
  class CheckCheckeoUsuario < ApplicationRecord
    self.table_name = "check_checkeo_usuarios"

    belongs_to :check_usuario, class_name: 'Camioneta::CheckUsuario'
    belongs_to :check_checkeo, class_name: 'Camioneta::CheckCheckeo'

    enum estado_eliminacion: {
      sin_solicitud: 0,
      aprueba_eliminar: 1,
      rechaza_eliminar: 2
    }
  end
end