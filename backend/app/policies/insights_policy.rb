class InsightsPolicy < ApplicationPolicy
  def show? = user.present?
end
