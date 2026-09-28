require "rails_helper"

RSpec.describe "CSRF protection", type: :request do
  let(:allowed_origin) { Rails.configuration.x.frontend_origin }
  let!(:user) { create(:user, :hr_manager, email_address: "hr@acme.test") }
  let(:credentials) { { email_address: "hr@acme.test", password: "correct-horse-battery" }.to_json }

  def log_in(headers)
    post "/api/v1/session", params: credentials, headers: { "Content-Type" => "application/json" }.merge(headers)
  end

  describe "Origin check on state-changing requests" do
    it "accepts the frontend origin" do
      log_in("Origin" => allowed_origin)
      expect(response).to have_http_status(:created)
    end

    it "rejects a foreign origin before doing any work" do
      expect { log_in("Origin" => "https://evil.example") }.not_to change(Session, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "invalid_origin", "message" => "Request origin is not allowed" } ]
      )
    end

    it "rejects a request without an Origin header" do
      log_in("Origin" => nil)
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects look-alike origins" do
      [ "#{allowed_origin}.evil.example", "#{allowed_origin}:1234", allowed_origin.sub("http:", "https:") ].each do |origin|
        log_in("Origin" => origin)
        expect(response).to have_http_status(:forbidden), "expected #{origin} to be rejected"
      end
    end

    it "applies to authenticated writes too" do
      sign_in_as(user)
      delete "/api/v1/session", headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      get "/api/v1/session"
      expect(response).to have_http_status(:ok)
    end

    it "does not apply to safe reads" do
      sign_in_as(user)
      get "/api/v1/session", headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "JSON content type on requests with a body" do
    it "rejects form-encoded and plain-text bodies with 415" do
      [ "application/x-www-form-urlencoded", "text/plain" ].each do |type|
        log_in("Origin" => allowed_origin, "Content-Type" => type)

        expect(response).to have_http_status(:unsupported_media_type), "expected #{type} to be rejected"
        expect(response.parsed_body.dig("errors", 0, "code")).to eq("unsupported_media_type")
      end
    end

    it "rejects a well-formed multipart form with 415" do
      body = "--x\r\nContent-Disposition: form-data; name=\"email_address\"\r\n\r\nhr@acme.test\r\n--x--\r\n"
      post "/api/v1/session", params: body, headers: { "Origin" => allowed_origin, "Content-Type" => "multipart/form-data; boundary=x" }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "accepts JSON with a charset" do
      log_in("Origin" => allowed_origin, "Content-Type" => "application/json; charset=utf-8")
      expect(response).to have_http_status(:created)
    end

    it "does not require a content type for DELETE" do
      sign_in_as(user)
      delete "/api/v1/session", headers: { "Origin" => allowed_origin }

      expect(response).to have_http_status(:no_content)
    end
  end
end
