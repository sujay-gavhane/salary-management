class InvalidParameterError < StandardError
  attr_reader :field, :detail

  def initialize(field, detail)
    @field = field.to_s
    @detail = detail
    super("#{@field} #{detail}")
  end
end
