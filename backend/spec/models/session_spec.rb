require "rails_helper"

RSpec.describe Session, type: :model do
  it { is_expected.to belong_to(:user) }

  describe "#expired?" do
    let(:session) { create(:session) }

    it "is false within the lifetime" do
      travel_to(session.created_at + Session::LIFETIME - 1.minute) do
        expect(session).not_to be_expired
      end
    end

    it "is true once the lifetime has passed" do
      travel_to(session.created_at + Session::LIFETIME + 1.second) do
        expect(session).to be_expired
      end
    end
  end

  it "has a 12 hour lifetime" do
    expect(Session::LIFETIME).to eq(12.hours)
  end
end
