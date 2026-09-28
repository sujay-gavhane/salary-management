module OriginCheck
  extend ActiveSupport::Concern

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze
  BODY_METHODS = %w[POST PUT PATCH].freeze

  included do
    before_action :verify_request_origin
    before_action :verify_json_content_type
  end

  private
    # CSRF defence alongside the SameSite=Lax cookie: browsers always send Origin on writes.
    def verify_request_origin
      return if request.method.in?(SAFE_METHODS)
      return if request.origin == Rails.configuration.x.frontend_origin

      render_error :forbidden, code: "invalid_origin", message: "Request origin is not allowed"
    end

    # HTML forms can't send application/json, so this also blocks form-based CSRF.
    def verify_json_content_type
      return unless request.method.in?(BODY_METHODS)
      return if request.media_type == "application/json"

      render_error :unsupported_media_type, code: "unsupported_media_type", message: "Content-Type must be application/json"
    end
end
