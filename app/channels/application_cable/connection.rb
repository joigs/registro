module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_usuario

    def connect
      self.current_usuario = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:usuario_id]
      usuario = Camioneta::CheckUsuario.find_by(id: token)
      if usuario
        usuario
      else
        reject_unauthorized_connection
      end
    end
  end
end