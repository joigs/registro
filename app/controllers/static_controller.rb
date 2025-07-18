class StaticController < ApplicationController
  def offline
    render layout: false
  end
end
