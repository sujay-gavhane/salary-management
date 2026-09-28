require "rails_helper"

RSpec.describe "Api::V1::Session", type: :request do
  let(:password) { "correct-horse-battery" }
  let!(:user) { create(:user, :hr_manager, name: "Hannah HR", email_address: "hr@acme.test", password: password) }

  def log_in(email: "hr@acme.test", pass: password)
    post "/api/v1/session", params: { email_address: email, password: pass }, as: :json
  end

  def session_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n").split("\n").find { |c| c.start_with?("session_id=") }
  end

  describe "POST /api/v1/session" do
    it "logs in with valid credentials and returns the user" do
      log_in

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to eq(
        "id" => user.id, "name" => "Hannah HR", "email_address" => "hr@acme.test", "role" => "hr_manager"
      )
    end

    it "never returns the password digest" do
      log_in
      expect(response.body).not_to include("password")
    end

    it "sets a signed, httponly, SameSite=Lax session cookie that expires in 12 hours" do
      freeze_time do
        log_in

        cookie = session_cookie_header
        expect(cookie).to be_present
        expect(cookie).to match(/httponly/i)
        expect(cookie).to match(/samesite=lax/i)
        expect(cookie).to include("expires=#{12.hours.from_now.httpdate}")
      end
    end

    it "records the session with IP and user agent" do
      expect { log_in }.to change(user.sessions, :count).by(1)
      expect(user.sessions.last).to have_attributes(ip_address: "127.0.0.1")
    end

    it "accepts the email address in any case" do
      log_in(email: " HR@ACME.test ")
      expect(response).to have_http_status(:created)
    end

    it "rejects a wrong password with a generic error" do
      log_in(pass: "wrong-password-123")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "invalid_credentials", "message" => "Invalid email or password" } ]
      )
      expect(session_cookie_header).to be_nil
    end

    it "gives an unknown email the same error as a wrong password" do
      log_in(email: "nobody@acme.test")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Invalid email or password")
    end

    it "rejects missing or malformed credentials without raising" do
      post "/api/v1/session", params: { email_address: [ "x" ], password: { a: 1 } }, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/session", params: {}, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rate-limits login attempts to 10 per 3 minutes" do
      10.times { log_in(pass: "wrong-password-123") }
      expect(response).to have_http_status(:unauthorized)

      log_in
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("rate_limited")

      travel 3.minutes + 1.second do
        log_in
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "GET /api/v1/session" do
    it "returns 401 in the shared error format without a session" do
      get "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq(
        "errors" => [ { "code" => "unauthenticated", "message" => "You need to log in" } ]
      )
    end

    it "returns the current user with a valid session cookie" do
      log_in
      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "email_address")).to eq("hr@acme.test")
    end

    it "rejects a tampered cookie" do
      log_in
      cookies[:session_id] = user.sessions.last.id.to_s
      get "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a replayed cookie after 12 hours (expiry is signed into the cookie)" do
      log_in
      signed_value = cookies[:session_id]

      travel(Session::LIFETIME + 1.second) do
        cookies[:session_id] = signed_value
        get "/api/v1/session"
      end

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects and destroys a session row older than its lifetime" do
      log_in
      session_record = user.sessions.last
      session_record.update_column(:created_at, (Session::LIFETIME + 1.second).ago)

      get "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
      expect(Session.exists?(session_record.id)).to be(false)
    end
  end

  describe "DELETE /api/v1/session" do
    it "logs out, destroys the session, and invalidates the cookie" do
      log_in
      session_id = user.sessions.last.id

      delete "/api/v1/session"
      expect(response).to have_http_status(:no_content)
      expect(Session.exists?(session_id)).to be(false)

      get "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when not logged in" do
      delete "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
