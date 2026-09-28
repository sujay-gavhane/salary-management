class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    { id: @user.id, name: @user.name, email_address: @user.email_address, role: @user.role }
  end
end
