require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      authorize Employee
      head :ok
    end

    def create
      authorize Employee
      head :created
    end

    def show
      head :ok
    end
  end

  def log_in_as(user)
    cookies.signed[:session_id] = create(:session, user: user).id
  end

  before { request.headers["Origin"] = Rails.configuration.x.frontend_origin }

  it "returns 401 in the shared error format when not logged in" do
    get :index

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("errors", 0, "code")).to eq("unauthenticated")
  end

  it "runs the action when the policy permits it" do
    log_in_as(create(:user, :viewer))
    get :index

    expect(response).to have_http_status(:ok)
  end

  it "returns 403 in the shared error format when the policy forbids it" do
    log_in_as(create(:user, :viewer))
    post :create, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq(
      "errors" => [ { "code" => "forbidden", "message" => "You are not allowed to perform this action" } ]
    )
  end

  it "fails loudly when an action forgets to authorize" do
    log_in_as(create(:user, :admin))

    expect { get :show, params: { id: 1 } }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end
end
