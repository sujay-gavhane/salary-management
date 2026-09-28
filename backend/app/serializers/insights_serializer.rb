class InsightsSerializer
  def initialize(rows)
    @rows = rows
  end

  def as_json(*) = @rows.map { |row| format(row) }

  private

  def format(value)
    case value
    when Hash then value.transform_values { |v| format(v) }
    when BigDecimal then MoneyFormat.call(value)
    else value
    end
  end
end
