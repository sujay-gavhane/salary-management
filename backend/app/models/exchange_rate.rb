class ExchangeRate < ApplicationRecord
  normalizes :currency, with: ->(code) { code.strip.upcase }

  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }, uniqueness: true
  validates :rate_to_usd, presence: true, numericality: { greater_than: 0 }
  validates :as_of, presence: true
end
