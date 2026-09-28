FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email_address) { |n| "user#{n}@acme.test" }
    password { "correct-horse-battery" }
  end
end
