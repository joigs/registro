class HomeController < ApplicationController

  def index
    @user = Current.user
    redirect_to records_path
  end



end
