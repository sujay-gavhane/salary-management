module AuthHelpers
  def sign_in_as(user, password: "correct-horse-battery")
    post "/api/v1/session", params: { email_address: user.email_address, password: password }, as: :json
    raise "sign-in failed for #{user.email_address}: #{response.status}" unless response.status == 201
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
