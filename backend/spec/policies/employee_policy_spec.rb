require "rails_helper"

RSpec.describe EmployeePolicy do
  subject { described_class }

  let(:employee) { build_stubbed(:employee) }
  let(:admin) { build_stubbed(:user, :admin) }
  let(:hr_manager) { build_stubbed(:user, :hr_manager) }
  let(:viewer) { build_stubbed(:user, :viewer) }

  permissions :index?, :show? do
    it { is_expected.to permit(admin, employee) }
    it { is_expected.to permit(hr_manager, employee) }
    it { is_expected.to permit(viewer, employee) }
    it { is_expected.not_to permit(nil, employee) }
  end

  permissions :create?, :update?, :destroy? do
    it { is_expected.to permit(admin, employee) }
    it { is_expected.to permit(hr_manager, employee) }
    it { is_expected.not_to permit(viewer, employee) }
    it { is_expected.not_to permit(nil, employee) }
  end

  describe EmployeePolicy::Scope do
    it "gives every role access to all employees" do
      employees = create_list(:employee, 2)

      [ admin, hr_manager, viewer ].each do |user|
        expect(described_class.new(user, Employee.all).resolve).to match_array(employees)
      end
    end

    it "gives no access without a user" do
      create(:employee)
      expect(described_class.new(nil, Employee.all).resolve).to be_empty
    end
  end
end
