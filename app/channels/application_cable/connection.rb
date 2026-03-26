module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_usuario

    def connect
      self.current_usuario = find_verified_usuario
    end

    private

    def find_verified_usuario
      bearer_token = request.headers["Authorization"].to_s.sub(/\ABearer\s+/i, "").strip
      query_token  = request.params[:token].presence || request.params[:usuario_id].presence
      token = bearer_token.presence || query_token

      reject_unauthorized_connection if token.blank?

      usuario = Camioneta::CheckUsuario.find_by(id: token)
      usuario || reject_unauthorized_connection
    end
  end
end