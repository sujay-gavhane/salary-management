require "rails_helper"

RSpec.describe "GET /api/v1/employees", type: :request do
  let(:viewer) { create(:user, :viewer) }

  before do
    create(:exchange_rate, currency: "USD", rate_to_usd: "1")
    create(:exchange_rate, currency: "INR", rate_to_usd: "0.012")
  end

  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  it "returns 401 when not logged in" do
    get "/api/v1/employees"
    expect(response).to have_http_status(:unauthorized)
  end

  %i[admin hr_manager viewer].each do |role|
    it "lists employees for #{role}" do
      create(:employee)
      sign_in_as(create(:user, role))
      get "/api/v1/employees"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
    end
  end

  it "returns serialized rows with USD salary and pagination meta" do
    create(:employee, full_name: "Asha Rao", country: "IN", salary: "2400000")
    sign_in_as(viewer)
    get "/api/v1/employees"

    expect(response.parsed_body["data"].first).to include(
      "full_name" => "Asha Rao", "currency" => "INR", "salary" => "2400000.00", "salary_usd" => "28800.00"
    )
    expect(response.parsed_body["meta"]).to eq("page" => 1, "per_page" => 25, "total_count" => 1, "total_pages" => 1)
  end

  it "applies search, filters, sort, and pagination from the query string" do
    create(:employee, full_name: "Asha Rao", country: "IN", salary: "3000000")
    create(:employee, full_name: "Ravi Rao", country: "IN", salary: "2000000")
    create(:employee, full_name: "Rao Smith", country: "US", salary: "90000")
    sign_in_as(viewer)

    get "/api/v1/employees", params: { q: "rao", country: "IN", sort: "salary_usd", direction: "desc", per_page: 1, page: 2 }

    expect(response.parsed_body["data"].map { |e| e["full_name"] }).to eq([ "Ravi Rao" ])
    expect(response.parsed_body["meta"]).to include("page" => 2, "per_page" => 1, "total_count" => 2, "total_pages" => 2)
  end

  it "returns 400 in the shared error format for an invalid sort key" do
    sign_in_as(viewer)
    get "/api/v1/employees", params: { sort: "password_digest" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["errors"]).to eq(
      [ { "code" => "invalid_parameter", "field" => "sort", "message" => "must be one of: full_name, email, job_title, department, country, hire_date, salary_usd" } ]
    )
  end

  it "ignores array-valued filters instead of failing" do
    create(:employee)
    sign_in_as(viewer)
    get "/api/v1/employees", params: { country: [ "IN", "US" ] }

    expect(response).to have_http_status(:ok)
  end

  it "runs a constant number of queries regardless of page size (no N+1)" do
    create_list(:employee, 3, country: "IN")
    sign_in_as(viewer)
    small = count_queries { get "/api/v1/employees" }

    create_list(:employee, 20, country: "IN")
    large = count_queries { get "/api/v1/employees" }

    expect(large).to eq(small)
  end
end
