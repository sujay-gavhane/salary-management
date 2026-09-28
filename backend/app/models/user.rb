class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "admin", hr_manager: "hr_manager", viewer: "viewer" }, default: "viewer", validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, length: { maximum: 120 }
  validates :email_address, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 12 }, allow_nil: true

  after_update :end_other_sessions, if: :saved_change_to_password_digest?

  def manages_employees? = admin? || hr_manager?

  private

  # Keeps the session making the change (an admin updating their own password).
  def end_other_sessions
    sessions.where.not(id: Current.session&.id).delete_all
  end
end
