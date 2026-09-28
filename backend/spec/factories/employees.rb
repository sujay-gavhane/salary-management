FactoryBot.define do
  factory :employee do
    sequence(:full_name) { |n| "Employee #{n}" }
    sequence(:email) { |n| "employee#{n}@acme.test" }
    job_title { "Software Engineer" }
    department { "Engineering" }
    country { "US" }
    salary { "100000.00" }
    employment_type { "full_time" }
    hire_date { Date.new(2022, 1, 10) }

    # The currency FK needs a rate row; create a 1:1 rate unless the spec set one up.
    after(:build) do |employee|
      currency = Country.currency_for(employee.country)
      ExchangeRate.find_or_create_by!(currency: currency) { |rate| rate.assign_attributes(rate_to_usd: 1, as_of: Date.new(2026, 9, 1)) } if currency
    end
  end
end
