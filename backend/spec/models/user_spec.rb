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

  describe "role" do
    it do
      is_expected.to define_enum_for(:role)
        .with_values(admin: "admin", hr_manager: "hr_manager", viewer: "viewer")
        .backed_by_column_of_type(:string)
        .validating
    end

    it "defaults to the least-privileged role" do
      expect(User.new.role).to eq("viewer")
    end

    it "lets admins and HR managers manage employees, but not viewers" do
      expect(build(:user, :admin)).to be_manages_employees
      expect(build(:user, :hr_manager)).to be_manages_employees
      expect(build(:user, :viewer)).not_to be_manages_employees
    end
  end

  describe "database constraints" do
    it "enforces a unique email address" do
      create(:user, email_address: "hr@acme.test")
      duplicate = build(:user, email_address: "hr@acme.test")

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces a known role" do
      user = create(:user)
      sql = User.sanitize_sql_array([ "UPDATE users SET role = ? WHERE id = ?", "superuser", user.id ])

      expect { User.connection.execute(sql) }
        .to raise_error(ActiveRecord::StatementInvalid, /users_role_valid/)
    end
  end
end
