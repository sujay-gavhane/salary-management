module MoneyFormat
  # Exact 2-decimal string from BigDecimal; never goes through Float.
  def self.call(amount) = ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 2)
end
