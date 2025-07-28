# app/controllers/pausa/api/v1/app_users_controller.rb
module Pausa
  module Api
    module V1
      class AppUsersController < ApplicationController
        protect_from_forgery with: :null_session
        before_action :set_user, only: %i[show update destroy]

        def index
          render json: AppUser.all
        end

        def show
          render json: @user
        end

        def create
          user = AppUser.new(user_params)
          if user.save
            render json: user, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @user.update(user_params)
            render json: @user
          else
            render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @user.destroy
          head :no_content
        end

        private

        def set_user
          @user = AppUser.find(params[:id])
        end

        def user_params
          params.require(:app_user).permit(:email, :name)
        end
      end
    end
  end
end
