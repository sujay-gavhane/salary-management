class EmployeePolicy < ApplicationPolicy
  def index? = user.present?

  def show? = user.present?

  def create? = !!user&.manages_employees?

  def update? = create?

  def destroy? = create?

  class Scope < ApplicationPolicy::Scope
    def resolve = user ? scope.all : scope.none
  end
end
