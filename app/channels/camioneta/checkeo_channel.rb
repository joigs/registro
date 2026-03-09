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
  end
end