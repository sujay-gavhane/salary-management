require "rails_helper"

RSpec.describe InsightsPolicy do
  subject { described_class }

  permissions :show? do
    it { is_expected.to permit(build_stubbed(:user, :admin), :insights) }
    it { is_expected.to permit(build_stubbed(:user, :hr_manager), :insights) }
    it { is_expected.to permit(build_stubbed(:user, :viewer), :insights) }
    it { is_expected.not_to permit(nil, :insights) }
  end
end
