module Api
  module V1
    class UsersController < ApplicationController
      # Admin gate runs before any lookup, so non-admins get 403 for every id, existing or not.
      before_action { authorize User, :index? }
      before_action :set_user, only: %i[update destroy]

      def index
        users = policy_scope(User).order(:name, :id)
        render json: { data: users.map { |user| UserSerializer.new(user).as_json } }
      end

      def create
        authorize User
        user = User.create!(permitted_attributes(User))
        render json: { data: UserSerializer.new(user).as_json }, status: :created
      end

      def update
        authorize @user
        @user.update!(permitted_attributes(@user))
        render json: { data: UserSerializer.new(@user).as_json }
      end

      def destroy
        authorize @user
        @user.destroy!
        head :no_content
      end

      private

      def set_user
        @user = policy_scope(User).find(params[:id])
      end
    end
  end
end
