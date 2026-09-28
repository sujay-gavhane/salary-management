class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ErrorHandling
  include Authentication
  include Pundit::Authorization

  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError do
    render_error :forbidden, code: "forbidden", message: "You are not allowed to perform this action"
  end

  private
    def pundit_user = Current.user
end
