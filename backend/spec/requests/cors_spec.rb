require "rails_helper"

RSpec.describe "CORS", type: :request do
  let(:allowed_origin) { Rails.configuration.x.frontend_origin }

  def preflight(origin)
    process :options, "/api/v1/employees", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "Content-Type"
    }
  end

  it "defaults the allowed origin to the Vite dev server outside production" do
    expect(allowed_origin).to eq("http://localhost:5173")
  end

  it "allows a credentialed preflight from the frontend origin" do
    preflight(allowed_origin)

    expect(response.headers["Access-Control-Allow-Origin"]).to eq(allowed_origin)
    expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
    expect(response.headers["Access-Control-Allow-Methods"]).to include("POST", "PATCH", "DELETE")
  end

  it "does not allow any other origin" do
    preflight("https://evil.example")

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    expect(response.headers["Access-Control-Allow-Credentials"]).to be_nil
  end

  it "only applies to the API" do
    process :options, "/up", headers: { "Origin" => allowed_origin, "Access-Control-Request-Method" => "GET" }
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end
