module ErrorHandling
  extend ActiveSupport::Concern

  private
    def render_error(status, code:, message:, field: nil)
      render json: { errors: [ { code:, field:, message: }.compact ] }, status:
    end
end
