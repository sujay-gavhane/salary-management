require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to be_valid }
    it { is_expected.to have_secure_password }
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(120) }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_length_of(:password).is_at_least(12) }

    it "rejects a malformed email address" do
      subject.email_address = "not-an-email"

      expect(subject).not_to be_valid
      expect(subject.errors[:email_address]).to include("is invalid")
    end

    it "rejects a duplicate email address regardless of case" do
      create(:user, email_address: "hr@acme.test")
      subject.email_address = "HR@acme.test"

      expect(subject).not_to be_valid
      expect(subject.errors[:email_address]).to include("has already been taken")
    end

    it "allows updating other attributes without re-entering the password" do
      user = create(:user)
      expect(User.find(user.id).update(name: "Renamed")).to be(true)
    end
  end

  describe "normalization" do
    it "downcases and strips the email address" do
      expect(build(:user, email_address: " HR@Acme.Test ").email_address).to eq("hr@acme.test")
    end
  end

  describe "database constraints" do
    it "enforces a unique email address" do
      create(:user, email_address: "hr@acme.test")
      duplicate = build(:user, email_address: "hr@acme.test")

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
