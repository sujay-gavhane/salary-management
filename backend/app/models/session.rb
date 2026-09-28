class Session < ApplicationRecord
  LIFETIME = 12.hours

  belongs_to :user

  def expires_at = created_at + LIFETIME

  def expired? = Time.current >= expires_at
end
