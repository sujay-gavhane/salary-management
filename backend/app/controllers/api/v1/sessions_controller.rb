module Api
  module V1
    class SessionsController < ApplicationController
      allow_unauthenticated_access only: :create
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
        render_error :too_many_requests, code: "rate_limited", message: "Too many login attempts. Try again later."
      }

      def create
        user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)

        if user
          start_new_session_for(user)
          render json: { data: UserSerializer.new(user).as_json }, status: :created
        else
          render_error :unauthorized, code: "invalid_credentials", message: "Invalid email or password"
        end
      end

      def show
        render json: { data: UserSerializer.new(Current.user).as_json }
      end

      def destroy
        terminate_session
        head :no_content
      end
    end
  end
end
