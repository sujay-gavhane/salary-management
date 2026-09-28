class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ErrorHandling
  include OriginCheck
  include Authentication
  include Pundit::Authorization

  after_action :verify_authorized

  private
    def pundit_user = Current.user
end
