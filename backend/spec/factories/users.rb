FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email_address) { |n| "user#{n}@acme.test" }
    password { "correct-horse-battery" }

    trait(:admin) { role { "admin" } }
    trait(:hr_manager) { role { "hr_manager" } }
    trait(:viewer) { role { "viewer" } }
  end
end
