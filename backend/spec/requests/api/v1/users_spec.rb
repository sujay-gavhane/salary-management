require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:password) { "correct-horse-battery" }
  let!(:admin) { create(:user, :admin, name: "Ada Admin", email_address: "admin@acme.test") }
  let!(:hr_manager) { create(:user, :hr_manager, name: "Hannah HR", email_address: "hr@acme.test") }
  let!(:viewer) { create(:user, :viewer, name: "Victor Viewer", email_address: "viewer@acme.test") }

  let(:new_user_params) do
    { user: { name: "Nina New", email_address: "nina@acme.test", password: "a-long-new-password", role: "hr_manager" } }
  end

  describe "GET /api/v1/users" do
    it "lists all users by name for an admin, without password digests" do
      sign_in_as(admin)
      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].map { |u| u["name"] }).to eq([ "Ada Admin", "Hannah HR", "Victor Viewer" ])
      expect(response.parsed_body["data"].first).to eq(
        "id" => admin.id, "name" => "Ada Admin", "email_address" => "admin@acme.test", "role" => "admin"
      )
      expect(response.body).not_to include("password")
    end

    %i[hr_manager viewer].each do |role|
      it "forbids #{role}" do
        sign_in_as(public_send(role))
        get "/api/v1/users"

        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 401 when not logged in" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/users" do
    it "creates a user with the given role for an admin" do
      sign_in_as(admin)

      expect { post "/api/v1/users", params: new_user_params, as: :json }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("name" => "Nina New", "email_address" => "nina@acme.test", "role" => "hr_manager")
      expect(User.authenticate_by(email_address: "nina@acme.test", password: "a-long-new-password")).to be_present
    end

    it "defaults the role to viewer" do
      sign_in_as(admin)
      post "/api/v1/users", params: { user: new_user_params[:user].except(:role) }, as: :json

      expect(response.parsed_body.dig("data", "role")).to eq("viewer")
    end

    it "returns 422 with field errors for invalid input" do
      sign_in_as(admin)
      post "/api/v1/users", params: { user: { name: "X", email_address: "hr@acme.test", password: "short", role: "superuser" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].map { |e| e["field"] }).to contain_exactly("email_address", "password", "role")
    end

    it "requires a password" do
      sign_in_as(admin)
      post "/api/v1/users", params: { user: new_user_params[:user].except(:password) }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include(include("field" => "password", "message" => "can't be blank"))
    end

    it "returns 400 without a user payload" do
      sign_in_as(admin)
      post "/api/v1/users", params: { unrelated: "value" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    %i[hr_manager viewer].each do |role|
      it "forbids #{role} and creates nothing" do
        sign_in_as(public_send(role))

        expect { post "/api/v1/users", params: new_user_params, as: :json }.not_to change(User, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/users/:id" do
    it "lets an admin change another user's name and role" do
      sign_in_as(admin)
      patch "/api/v1/users/#{viewer.id}", params: { user: { name: "Victor Promoted", role: "hr_manager" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(viewer.reload).to have_attributes(name: "Victor Promoted", role: "hr_manager")
    end

    it "ignores an admin's attempt to change their own role but applies other changes" do
      sign_in_as(admin)
      patch "/api/v1/users/#{admin.id}", params: { user: { name: "Ada Renamed", role: "viewer" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(admin.reload).to have_attributes(name: "Ada Renamed", role: "admin")
    end

    it "resets another user's password and ends their sessions" do
      create_list(:session, 2, user: viewer)
      sign_in_as(admin)
      patch "/api/v1/users/#{viewer.id}", params: { user: { password: "a-brand-new-password" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(viewer.sessions.count).to eq(0)
      expect(User.authenticate_by(email_address: viewer.email_address, password: "a-brand-new-password")).to eq(viewer)
    end

    it "keeps the admin's current session when they change their own password" do
      other_session = create(:session, user: admin)
      sign_in_as(admin)
      patch "/api/v1/users/#{admin.id}", params: { user: { password: "a-brand-new-password" } }, as: :json

      expect(Session.exists?(other_session.id)).to be(false)
      get "/api/v1/session"
      expect(response).to have_http_status(:ok)
    end

    it "leaves the password unchanged when it is blank" do
      sign_in_as(admin)
      patch "/api/v1/users/#{viewer.id}", params: { user: { name: "Still Victor", password: "" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(User.authenticate_by(email_address: viewer.email_address, password: password)).to eq(viewer)
    end

    it "returns 422 for invalid changes" do
      sign_in_as(admin)
      patch "/api/v1/users/#{viewer.id}", params: { user: { email_address: "hr@acme.test" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown user" do
      sign_in_as(admin)
      patch "/api/v1/users/0", params: { user: { name: "Ghost" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    %i[hr_manager viewer].each do |role|
      it "forbids #{role}, including for their own account" do
        sign_in_as(public_send(role))
        patch "/api/v1/users/#{public_send(role).id}", params: { user: { role: "admin" } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(public_send(role).reload.role).to eq(role.to_s)
      end
    end

    it "returns 403 rather than 404 to non-admins, so user ids can't be probed" do
      sign_in_as(hr_manager)
      patch "/api/v1/users/0", params: { user: { name: "Ghost" } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/users/:id" do
    it "lets an admin delete another user and their sessions" do
      create(:session, user: viewer)
      sign_in_as(admin)

      expect { delete "/api/v1/users/#{viewer.id}" }.to change(User, :count).by(-1).and change(Session, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "forbids an admin from deleting themselves" do
      sign_in_as(admin)

      expect { delete "/api/v1/users/#{admin.id}" }.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    %i[hr_manager viewer].each do |role|
      it "forbids #{role}" do
        sign_in_as(public_send(role))

        expect { delete "/api/v1/users/#{admin.id}" }.not_to change(User, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 404 for an unknown user" do
      sign_in_as(admin)
      delete "/api/v1/users/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
