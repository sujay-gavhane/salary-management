class InsightsPolicy < ApplicationPolicy
  def show? = user.present? && (user.admin? || user.hr_manager?)
end
