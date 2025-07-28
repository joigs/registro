# frozen_string_literal: true

module Pausa
  class HomeController < ApplicationController
    layout "pausa"
    skip_before_action :protect_pages
    def index; end
  end
end
