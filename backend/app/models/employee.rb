class Employee < ApplicationRecord
  DEPARTMENTS = %w[Engineering Product Design Sales Marketing Finance HR Operations Support Legal].freeze

  belongs_to :exchange_rate, foreign_key: :currency, primary_key: :currency, inverse_of: false

  enum :employment_type, { full_time: "full_time", part_time: "part_time", contract: "contract" }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, with: ->(name) { name.squish }
  normalizes :country, with: ->(code) { code.strip.upcase }

  before_validation :derive_currency

  validates :full_name, presence: true, length: { in: 2..120 }
  validates :email, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :job_title, presence: true, length: { maximum: 100 }
  validates :department, presence: true, inclusion: { in: DEPARTMENTS }
  validates :country, presence: true, inclusion: { in: Country.codes }
  validates :salary, presence: true, numericality: { greater_than: 0, less_than: 10_000_000_000 }
  validates :hire_date, presence: true
  validate :hire_date_not_in_future

  private

  def derive_currency
    self.currency = Country.currency_for(country)
  end

  def hire_date_not_in_future
    errors.add(:hire_date, "can't be in the future") if hire_date&.future?
  end
end
