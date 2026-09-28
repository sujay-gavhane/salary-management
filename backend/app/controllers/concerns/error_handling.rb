module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::ParameterMissing do |error|
      render_error :bad_request, code: "bad_request", message: error.message
    end

    rescue_from ActiveRecord::RecordNotFound do |error|
      render_error :not_found, code: "not_found", message: "#{error.model || 'Record'} not found"
    end

    rescue_from ActiveRecord::RecordInvalid do |error|
      errors = error.record.errors.map do |e|
        { code: "validation_failed", field: e.attribute.to_s, message: e.message }
      end
      render json: { errors: }, status: :unprocessable_content
    end

    rescue_from Pundit::NotAuthorizedError do
      render_error :forbidden, code: "forbidden", message: "You are not allowed to perform this action"
    end
  end

  private
    def render_error(status, code:, message:, field: nil)
      render json: { errors: [ { code:, field:, message: }.compact ] }, status:
    end
end
