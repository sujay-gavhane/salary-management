FactoryBot.define do
  factory :exchange_rate do
    sequence(:currency, "AAA")
    rate_to_usd { "1.00000000" }
    as_of { Date.new(2026, 9, 1) }
  end
end
