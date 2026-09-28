require "rails_helper"

RSpec.describe "Api::V1::Employees CRUD", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:hr_manager) { create(:user, :hr_manager) }
  let(:viewer) { create(:user, :viewer) }

  let!(:inr) { create(:exchange_rate, currency: "INR", rate_to_usd: "0.012") }
  let!(:employee) do
    create(:employee, full_name: "Asha Rao", email: "asha.rao@acme.test", country: "IN",
      salary: "2400000.00", job_title: "Software Engineer", department: "Engineering",
      employment_type: "full_time", hire_date: Date.new(2021, 4, 12))
  end

  let(:valid_params) do
    {
      employee: {
        full_name: "Liam Chen", email: "liam.chen@acme.test", job_title: "Product Manager",
        department: "Product", country: "IN", salary: "3100000.50",
        employment_type: "contract", hire_date: "2023-02-01"
      }
    }
  end

  describe "GET /api/v1/employees/:id" do
    %i[admin hr_manager viewer].each do |role|
      it "returns the employee with local and USD salary for #{role}" do
        sign_in_as(public_send(role))
        get "/api/v1/employees/#{employee.id}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq(
          "id" => employee.id, "full_name" => "Asha Rao", "email" => "asha.rao@acme.test",
          "job_title" => "Software Engineer", "department" => "Engineering",
          "country" => "IN", "currency" => "INR",
          "salary" => "2400000.00", "salary_usd" => "28800.00",
          "employment_type" => "full_time", "hire_date" => "2021-04-12"
        )
      end
    end

    it "returns 404 for an unknown id" do
      sign_in_as(viewer)
      get "/api/v1/employees/0"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("errors" => [ { "code" => "not_found", "message" => "Employee not found" } ])
    end

    it "returns 401 when not logged in" do
      get "/api/v1/employees/#{employee.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/employees" do
    %i[admin hr_manager].each do |role|
      it "creates an employee for #{role}, deriving the currency from the country" do
        sign_in_as(public_send(role))

        expect { post "/api/v1/employees", params: valid_params, as: :json }.to change(Employee, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body["data"]).to include(
          "full_name" => "Liam Chen", "country" => "IN", "currency" => "INR",
          "salary" => "3100000.50", "salary_usd" => "37200.01", "employment_type" => "contract"
        )
      end
    end

    it "forbids a viewer and creates nothing" do
      sign_in_as(viewer)

      expect { post "/api/v1/employees", params: valid_params, as: :json }.not_to change(Employee, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "checks permissions before validating input" do
      sign_in_as(viewer)
      post "/api/v1/employees", params: { employee: { full_name: "" } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 with one error per invalid field" do
      sign_in_as(hr_manager)
      post "/api/v1/employees", params: { employee: valid_params[:employee].merge(email: "asha.rao@acme.test", salary: "-5") }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to contain_exactly(
        { "code" => "validation_failed", "field" => "email", "message" => "has already been taken" },
        { "code" => "validation_failed", "field" => "salary", "message" => "must be greater than 0" }
      )
    end

    it "returns 400 when the payload has no employee attributes" do
      sign_in_as(hr_manager)
      post "/api/v1/employees", params: { unrelated: "value" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("bad_request")
    end

    it "ignores attributes that are not permitted" do
      sign_in_as(hr_manager)
      post "/api/v1/employees", params: { employee: valid_params[:employee].merge(id: 999_999, currency: "USD") }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "id")).not_to eq(999_999)
      expect(response.parsed_body.dig("data", "currency")).to eq("INR")
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    %i[admin hr_manager].each do |role|
      it "updates the employee for #{role}" do
        sign_in_as(public_send(role))
        patch "/api/v1/employees/#{employee.id}", params: { employee: { job_title: "Staff Engineer", salary: "2600000" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to include("job_title" => "Staff Engineer", "salary" => "2600000.00")
        expect(employee.reload.job_title).to eq("Staff Engineer")
      end
    end

    it "moves the currency with the country" do
      create(:exchange_rate, currency: "GBP", rate_to_usd: "1.27")
      sign_in_as(hr_manager)
      patch "/api/v1/employees/#{employee.id}", params: { employee: { country: "GB", salary: "90000" } }, as: :json

      expect(response.parsed_body["data"]).to include("country" => "GB", "currency" => "GBP", "salary_usd" => "114300.00")
    end

    it "forbids a viewer and changes nothing" do
      sign_in_as(viewer)
      patch "/api/v1/employees/#{employee.id}", params: { employee: { job_title: "Hacked" } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(employee.reload.job_title).to eq("Software Engineer")
    end

    it "returns 422 for invalid changes" do
      sign_in_as(hr_manager)
      patch "/api/v1/employees/#{employee.id}", params: { employee: { hire_date: (Date.current + 1).iso8601 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq(
        [ { "code" => "validation_failed", "field" => "hire_date", "message" => "can't be in the future" } ]
      )
    end

    it "returns 404 for an unknown id" do
      sign_in_as(hr_manager)
      patch "/api/v1/employees/0", params: { employee: { job_title: "X" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/employees/:id" do
    %i[admin hr_manager].each do |role|
      it "deletes the employee for #{role}" do
        sign_in_as(public_send(role))

        expect { delete "/api/v1/employees/#{employee.id}" }.to change(Employee, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    it "forbids a viewer and deletes nothing" do
      sign_in_as(viewer)

      expect { delete "/api/v1/employees/#{employee.id}" }.not_to change(Employee, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for an unknown id" do
      sign_in_as(admin)
      delete "/api/v1/employees/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
