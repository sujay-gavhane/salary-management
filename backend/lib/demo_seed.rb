class DemoSeed
  SEED = 20_260_901
  DEFAULT_COUNT = 10_000
  BATCH_SIZE = 1_000
  HIRE_START = Date.new(2012, 1, 1)
  HIRE_DAYS = (Date.new(2026, 6, 30) - HIRE_START).to_i
  EMAIL_DOMAIN = "acme.test".freeze

  RATES_AS_OF = Date.new(2026, 9, 1)
  RATES_TO_USD = {
    "USD" => BigDecimal("1"),
    "GBP" => BigDecimal("1.27"),
    "EUR" => BigDecimal("1.08"),
    "CAD" => BigDecimal("0.73"),
    "INR" => BigDecimal("0.012"),
    "SGD" => BigDecimal("0.74"),
    "JPY" => BigDecimal("0.0067"),
    "AUD" => BigDecimal("0.66")
  }.freeze

  USERS = {
    admin: { name: "Ada Admin", email_address: "admin@acme.test", env: "ADMIN_PASSWORD", dev_password: "acme-admin-dev-2026" },
    hr_manager: { name: "Hannah HR", email_address: "hr@acme.test", env: "HR_PASSWORD", dev_password: "acme-hr-dev-2026" },
    viewer: { name: "Victor Viewer", email_address: "viewer@acme.test", env: "VIEWER_PASSWORD", dev_password: "acme-viewer-dev-2026" }
  }.freeze

  # pay_factor: local pay level relative to the US. SG/JP use the generic locale; Faker's ja names are kanji.
  COUNTRIES = {
    "US" => { weight: 30, pay_factor: 1.0, locale: "en-US" },
    "IN" => { weight: 22, pay_factor: 0.28, locale: "en-IND" },
    "GB" => { weight: 12, pay_factor: 0.75, locale: "en-GB" },
    "DE" => { weight: 8, pay_factor: 0.75, locale: "de" },
    "CA" => { weight: 7, pay_factor: 0.78, locale: "en-CA" },
    "AU" => { weight: 6, pay_factor: 0.80, locale: "en-AU" },
    "NL" => { weight: 5, pay_factor: 0.72, locale: "nl" },
    "SG" => { weight: 5, pay_factor: 0.70, locale: "en" },
    "JP" => { weight: 5, pay_factor: 0.60, locale: "en" }
  }.freeze

  # base_usd: annual pay at US levels; title values are seniority multipliers.
  DEPARTMENTS = {
    "Engineering" => { weight: 30, base_usd: 110_000, titles: {
      "Software Engineer" => 1.0, "Senior Software Engineer" => 1.35, "Staff Engineer" => 1.75,
      "Engineering Manager" => 1.8, "QA Engineer" => 0.85, "DevOps Engineer" => 1.1
    } },
    "Sales" => { weight: 15, base_usd: 75_000, titles: {
      "Sales Development Representative" => 0.7, "Account Executive" => 1.0,
      "Senior Account Executive" => 1.3, "Sales Manager" => 1.6
    } },
    "Support" => { weight: 10, base_usd: 55_000, titles: {
      "Support Specialist" => 1.0, "Senior Support Specialist" => 1.25, "Support Manager" => 1.6
    } },
    "Operations" => { weight: 10, base_usd: 65_000, titles: { "Operations Analyst" => 1.0, "Operations Manager" => 1.5 } },
    "Marketing" => { weight: 8, base_usd: 80_000, titles: {
      "Marketing Specialist" => 1.0, "Content Strategist" => 0.95, "Marketing Manager" => 1.45
    } },
    "Product" => { weight: 7, base_usd: 115_000, titles: {
      "Product Manager" => 1.0, "Senior Product Manager" => 1.3, "Director of Product" => 1.7
    } },
    "Finance" => { weight: 6, base_usd: 85_000, titles: {
      "Accountant" => 1.0, "Financial Analyst" => 1.1, "Finance Manager" => 1.5
    } },
    "Design" => { weight: 5, base_usd: 95_000, titles: {
      "Product Designer" => 1.0, "Senior Product Designer" => 1.3, "Design Manager" => 1.6
    } },
    "HR" => { weight: 5, base_usd: 70_000, titles: {
      "HR Generalist" => 1.0, "Recruiter" => 0.95, "HR Business Partner" => 1.35
    } },
    "Legal" => { weight: 4, base_usd: 120_000, titles: { "Legal Counsel" => 1.0, "Senior Legal Counsel" => 1.35 } }
  }.freeze

  EMPLOYMENT_TYPES = {
    "full_time" => { weight: 85, pay_factor: 1.0 },
    "contract" => { weight: 10, pay_factor: 1.1 },
    "part_time" => { weight: 5, pay_factor: 0.5 }
  }.freeze

  def initialize(count: DEFAULT_COUNT, batch_size: BATCH_SIZE, reset: false)
    @count = count
    @batch_size = batch_size
    @reset = reset
  end

  def call
    seed_exchange_rates
    seed_users
    { exchange_rates: RATES_TO_USD.size, users: USERS.size, employees: seed_employees }
  end

  private

  def seed_exchange_rates
    rows = RATES_TO_USD.map { |currency, rate| { currency:, rate_to_usd: rate, as_of: RATES_AS_OF } }
    ExchangeRate.upsert_all(rows, unique_by: :currency)
  end

  # Existing users are left alone, so re-seeding never resets a changed password.
  def seed_users
    USERS.each do |role, attrs|
      User.find_or_create_by!(email_address: attrs[:email_address]) do |user|
        user.name = attrs[:name]
        user.role = role
        user.password = Rails.env.production? ? ENV.fetch(attrs[:env]) : ENV.fetch(attrs[:env], attrs[:dev_password])
      end
    end
  end

  def seed_employees
    return :skipped if Employee.exists? && !@reset

    Employee.transaction do
      Employee.delete_all
      rows = generate_rows
      rows.each_slice(@batch_size) { |batch| Employee.insert_all!(batch) }
    end
    @count
  end

  def generate_rows
    Faker::Config.random = Random.new(SEED)
    rng = Random.new(SEED)
    emails = Set.new

    Array.new(@count) { build_row(rng, emails) }
  ensure
    Faker::Config.random = nil
  end

  def build_row(rng, emails)
    country = pick(rng, COUNTRIES)
    department = pick(rng, DEPARTMENTS)
    employment_type = pick(rng, EMPLOYMENT_TYPES)
    job_title, seniority = DEPARTMENTS[department][:titles].to_a.sample(random: rng)
    currency = Country.currency_for(country)

    full_name = Faker::Base.with_locale(COUNTRIES[country][:locale]) { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }
    salary_usd = DEPARTMENTS[department][:base_usd] * seniority * COUNTRIES[country][:pay_factor] *
      EMPLOYMENT_TYPES[employment_type][:pay_factor] * rng.rand(0.85..1.15)

    {
      full_name:,
      email: unique_email(full_name, emails),
      job_title:,
      department:,
      country:,
      currency:,
      salary: (BigDecimal(salary_usd, 12) / RATES_TO_USD[currency]).round(-2),
      employment_type:,
      hire_date: HIRE_START + rng.rand(HIRE_DAYS + 1)
    }
  end

  def pick(rng, options)
    target = rng.rand(options.sum { |_, option| option[:weight] })
    options.each do |key, option|
      target -= option[:weight]
      return key if target.negative?
    end
  end

  def unique_email(full_name, taken)
    local = full_name.parameterize(separator: ".")
    email = "#{local}@#{EMAIL_DOMAIN}"
    suffix = 1
    email = "#{local}#{suffix += 1}@#{EMAIL_DOMAIN}" while taken.include?(email)
    taken << email
    email
  end
end
