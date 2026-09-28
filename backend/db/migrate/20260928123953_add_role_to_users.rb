class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, null: false, default: "viewer"
    add_check_constraint :users, "role IN ('admin', 'hr_manager', 'viewer')", name: "users_role_valid"
  end
end
