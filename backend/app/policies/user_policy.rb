class UserPolicy < ApplicationPolicy
  def index? = admin?

  def show? = admin?

  def create? = admin?

  def update? = admin?

  # Admins can't delete or demote themselves, so the acting admin always remains.
  def destroy? = admin? && record != user

  def permitted_attributes
    attributes = %i[name email_address password]
    record == user ? attributes : attributes + [ :role ]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end

  private

  def admin? = !!user&.admin?
end
