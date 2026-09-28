require "rails_helper"

RSpec.describe DemoSeed do
  def run(**options) = described_class.new(count: 300, **options).call

  describe "exchange rates" do
    it "seeds a dated rate for every supported currency" do
      run

      expect(ExchangeRate.pluck(:currency)).to match_array(Country.currencies)
      expect(ExchangeRate.pluck(:as_of).uniq).to eq([ DemoSeed::RATES_AS_OF ])
      expect(ExchangeRate.find("USD").rate_to_usd).to eq(1)
    end

    it "updates existing rates in place instead of duplicating them" do
      create(:exchange_rate, currency: "INR", rate_to_usd: "0.5", as_of: Date.new(2020, 1, 1))
      run

      expect(ExchangeRate.find("INR")).to have_attributes(rate_to_usd: DemoSeed::RATES_TO_USD["INR"], as_of: DemoSeed::RATES_AS_OF)
    end
  end

  describe "users" do
    it "creates one demo user per role with the dev default passwords" do
      run

      DemoSeed::USERS.each do |role, attrs|
        user = User.authenticate_by(email_address: attrs[:email_address], password: attrs[:dev_password])
        expect(user).to be_present, "expected #{role} to log in with the dev password"
        expect(user.role).to eq(role.to_s)
      end
    end

    it "uses passwords from the environment when set" do
      stub_const("ENV", ENV.to_h.merge("HR_PASSWORD" => "an-env-provided-password"))
      run

      expect(User.authenticate_by(email_address: "hr@acme.test", password: "an-env-provided-password")).to be_present
    end

    it "requires passwords from the environment in production" do
      allow(Rails.env).to receive(:production?).and_return(true)
      stub_const("ENV", ENV.to_h.except("ADMIN_PASSWORD", "HR_PASSWORD", "VIEWER_PASSWORD"))

      expect { run }.to raise_error(KeyError, /ADMIN_PASSWORD/)
    end

    it "leaves existing users and their passwords untouched" do
      create(:user, :viewer, email_address: "admin@acme.test", password: "a-changed-password")
      run

      expect(User.where(email_address: "admin@acme.test").count).to eq(1)
      expect(User.authenticate_by(email_address: "admin@acme.test", password: "a-changed-password").role).to eq("viewer")
    end
  end

  describe "employees" do
    it "creates the requested number of valid employees" do
      run

      expect(Employee.count).to eq(300)
      invalid = Employee.includes(:exchange_rate).reject(&:valid?)
      expect(invalid).to be_empty, "invalid: #{invalid.first&.errors&.full_messages}"
    end

    it "sets each employee's currency from their country" do
      run
      Employee.distinct.pluck(:country, :currency).each do |country, currency|
        expect(currency).to eq(Country.currency_for(country))
      end
    end

    it "spreads employees across every country, department, and employment type" do
      run

      expect(Employee.distinct.pluck(:country)).to match_array(Country.codes)
      expect(Employee.distinct.pluck(:department)).to match_array(Employee::DEPARTMENTS)
      expect(Employee.distinct.pluck(:employment_type)).to match_array(Employee.employment_types.values)
    end

    it "gives realistic, currency-appropriate salaries" do
      run
      usd = Employee.joins(:exchange_rate).pluck(Arel.sql("employees.salary * exchange_rates.rate_to_usd"))

      expect(usd.min).to be >= 5_000
      expect(usd.max).to be <= 500_000
      expect(Employee.where(country: "JP").minimum(:salary)).to be > 1_000_000
    end

    it "only uses hire dates in the past" do
      run
      expect(Employee.maximum(:hire_date)).to be <= Date.current
    end

    it "is deterministic across runs" do
      run
      first = Employee.order(:email).pluck(:full_name, :email, :country, :job_title, :salary)

      run(reset: true)
      expect(Employee.order(:email).pluck(:full_name, :email, :country, :job_title, :salary)).to eq(first)
    end

    it "skips employees when some already exist" do
      create(:employee)
      result = run

      expect(Employee.count).to eq(1)
      expect(result[:employees]).to eq(:skipped)
    end

    it "replaces existing employees when reset" do
      create(:employee, email: "keep.me@acme.test")
      run(reset: true)

      expect(Employee.count).to eq(300)
      expect(Employee.exists?(email: "keep.me@acme.test")).to be(false)
    end

    it "inserts in batches rather than row by row" do
      expect(Employee).to receive(:insert_all!).exactly(3).times.and_call_original
      described_class.new(count: 250, batch_size: 100).call
    end
  end
end
