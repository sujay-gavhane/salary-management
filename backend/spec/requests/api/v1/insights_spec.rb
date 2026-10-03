require "rails_helper"

RSpec.describe "Api::V1::Insights", type: :request do
  let(:viewer) { create(:user, :viewer) }

  before do
    create(:exchange_rate, currency: "INR", rate_to_usd: "0.012", as_of: Date.new(2026, 9, 1))
    create(:employee, country: "IN", job_title: "Engineer", salary: "1000000")
    create(:employee, country: "IN", job_title: "Engineer", salary: "2000000")
  end

  describe "GET /api/v1/insights/summary" do
    it "returns 401 when not logged in" do
      get "/api/v1/insights/summary"
      expect(response).to have_http_status(:unauthorized)
    end

    %i[admin hr_manager].each do |role|
      it "is available to #{role}" do
        sign_in_as(create(:user, role))
        get "/api/v1/insights/summary"

        expect(response).to have_http_status(:ok)
      end
    end

    it "forbids viewers" do
      sign_in_as(viewer)
      get "/api/v1/insights/summary"

      expect(response).to have_http_status(:forbidden)
    end

    it "returns the org-wide summary with money as exact strings" do
      sign_in_as(create(:user, :hr_manager))
      get "/api/v1/insights/summary"

      expect(response.parsed_body).to eq(
        "data" => {
          "headcount" => 2,
          "by_country" => [ { "country" => "IN", "currency" => "INR", "headcount" => 2, "avg_usd" => "18000.00" } ],
          "by_department" => [ { "department" => "Engineering", "headcount" => 2, "avg_usd" => "18000.00" } ],
          "distribution" => {
            "bucket_size_usd" => "25000.00",
            "buckets" => [ { "min_usd" => "0.00", "max_usd" => "25000.00", "headcount" => 2 } ]
          }
        },
        "rates_as_of" => "2026-09-01"
      )
    end
  end

  describe "GET /api/v1/insights/countries" do
    it "returns 401 when not logged in" do
      get "/api/v1/insights/countries"
      expect(response).to have_http_status(:unauthorized)
    end

    %i[admin hr_manager].each do |role|
      it "is available to #{role}" do
        sign_in_as(create(:user, role))
        get "/api/v1/insights/countries"

        expect(response).to have_http_status(:ok)
      end
    end

    it "forbids viewers" do
      sign_in_as(viewer)
      get "/api/v1/insights/countries"

      expect(response).to have_http_status(:forbidden)
    end

    it "returns per-country stats as exact money strings with the rates date" do
      sign_in_as(create(:user, :hr_manager))
      get "/api/v1/insights/countries"

      expect(response.parsed_body).to eq(
        "data" => [ {
          "country" => "IN", "currency" => "INR", "headcount" => 2,
          "local" => { "min" => "1000000.00", "max" => "2000000.00", "avg" => "1500000.00", "median" => "1500000.00" },
          "usd" => { "min" => "12000.00", "max" => "24000.00", "avg" => "18000.00", "median" => "18000.00" }
        } ],
        "rates_as_of" => "2026-09-01"
      )
    end
  end

  describe "GET /api/v1/insights/job_titles" do
    it "returns job-title averages for the country with its currency" do
      sign_in_as(create(:user, :hr_manager))
      get "/api/v1/insights/job_titles", params: { country: "IN" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "data" => [ { "job_title" => "Engineer", "headcount" => 2, "local" => { "avg" => "1500000.00" }, "usd" => { "avg" => "18000.00" } } ],
        "country" => "IN", "currency" => "INR", "rates_as_of" => "2026-09-01"
      )
    end

    it "forbids viewers from job-title insights" do
      sign_in_as(viewer)
      get "/api/v1/insights/job_titles", params: { country: "IN" }

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 400 for a missing or unsupported country" do
      sign_in_as(create(:user, :hr_manager))

      [ {}, { country: "ZZ" } ].each do |params|
        get "/api/v1/insights/job_titles", params: params

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body.dig("errors", 0)).to include("code" => "invalid_parameter", "field" => "country")
      end
    end

    it "returns 401 when not logged in" do
      get "/api/v1/insights/job_titles", params: { country: "IN" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
