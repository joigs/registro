module ApplicationCable

  #esto esta siendo usado para camioneta
  class Connection < ActionCable::Connection::Base
    identified_by :current_usuario

    def connect
      self.current_usuario = find_verified_user
    end

    private

    def find_verified_user
      usuario_id = request.params[:usuario_id]
      usuario = Camioneta::CheckUsuario.find_by(id: usuario_id)
      if usuario
        usuario
      else
        reject_unauthorized_connection
      end
    end
  end
end