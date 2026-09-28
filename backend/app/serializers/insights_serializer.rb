class InsightsSerializer
  def initialize(data)
    @data = data
  end

  def as_json(*) = format(@data)

  private

  def format(value)
    case value
    when Array then value.map { |v| format(v) }
    when Hash then value.transform_values { |v| format(v) }
    when BigDecimal then MoneyFormat.call(value)
    else value
    end
  end
end
