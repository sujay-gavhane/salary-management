class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ErrorHandling
  include Authentication
end
