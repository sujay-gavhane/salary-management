require "rails_helper"

RSpec.describe UserPolicy do
  subject { described_class }

  let(:admin) { build_stubbed(:user, :admin) }
  let(:hr_manager) { build_stubbed(:user, :hr_manager) }
  let(:viewer) { build_stubbed(:user, :viewer) }
  let(:other_user) { build_stubbed(:user) }

  permissions :index?, :show?, :create?, :update? do
    it { is_expected.to permit(admin, other_user) }
    it { is_expected.not_to permit(hr_manager, other_user) }
    it { is_expected.not_to permit(viewer, other_user) }
    it { is_expected.not_to permit(nil, other_user) }
  end

  permissions :destroy? do
    it { is_expected.to permit(admin, other_user) }
    it { is_expected.not_to permit(admin, admin) }
    it { is_expected.not_to permit(hr_manager, other_user) }
    it { is_expected.not_to permit(viewer, other_user) }
  end

  describe "#permitted_attributes" do
    it "lets an admin change another user's role" do
      expect(described_class.new(admin, other_user).permitted_attributes)
        .to contain_exactly(:name, :email_address, :password, :role)
    end

    it "stops an admin from changing their own role" do
      expect(described_class.new(admin, admin).permitted_attributes)
        .to contain_exactly(:name, :email_address, :password)
    end
  end

  describe UserPolicy::Scope do
    let!(:users) { create_list(:user, 2) }

    it "gives admins all users" do
      expect(described_class.new(admin, User.all).resolve).to match_array(users)
    end

    it "gives other roles no users" do
      [ hr_manager, viewer, nil ].each do |user|
        expect(described_class.new(user, User.all).resolve).to be_empty
      end
    end
  end
end
