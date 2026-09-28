module Country
  CURRENCIES = {
    "US" => "USD",
    "GB" => "GBP",
    "DE" => "EUR",
    "NL" => "EUR",
    "CA" => "CAD",
    "IN" => "INR",
    "SG" => "SGD",
    "JP" => "JPY",
    "AU" => "AUD"
  }.freeze

  def self.codes = CURRENCIES.keys

  def self.currencies = CURRENCIES.values.uniq

  def self.currency_for(code) = CURRENCIES[code]
end
