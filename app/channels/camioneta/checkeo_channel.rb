module Camioneta
  class CheckeoChannel < ApplicationCable::Channel
    def subscribed
      checkeo = Camioneta::CheckCheckeo.find_by(id: params[:checkeo_id])
      if checkeo
        stream_for checkeo
      else
        reject
      end
    end

    def unsubscribed
    end

    def actualizar_campo(data)
      checkeo = Camioneta::CheckCheckeo.find_by(id: params[:checkeo_id])
      return unless checkeo

      campo = data['campo']
      valor = data['valor']
      usuario_id = data['usuario_id']

      if checkeo.has_attribute?(campo)
        if checkeo.update(campo => valor)
          Camioneta::CheckeoChannel.broadcast_to(
            checkeo,
            { campo: campo, valor: valor, usuario_id: usuario_id }
          )
        end
      end
    end
  end
end