require "rails_helper"

RSpec.describe Employee, type: :model do
  describe "validations" do
    subject { build(:employee) }

    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_length_of(:full_name).is_at_least(2).is_at_most(120) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:email).is_at_most(254) }

    it { is_expected.to validate_presence_of(:job_title) }
    it { is_expected.to validate_length_of(:job_title).is_at_most(100) }

    it { is_expected.to validate_presence_of(:department) }
    it { is_expected.to validate_inclusion_of(:department).in_array(Employee::DEPARTMENTS) }

    it { is_expected.to validate_presence_of(:salary) }
    it { is_expected.to validate_numericality_of(:salary).is_greater_than(0).is_less_than(10_000_000_000) }

    it { is_expected.to validate_presence_of(:hire_date) }

    it do
      is_expected.to define_enum_for(:employment_type)
        .with_values(full_time: "full_time", part_time: "part_time", contract: "contract")
        .backed_by_column_of_type(:string)
        .validating
    end

    it "rejects malformed emails" do
      [ "not-an-email", "a@", "@acme.test", "a b@acme.test" ].each do |email|
        subject.email = email
        expect(subject).not_to be_valid, "expected #{email.inspect} to be invalid"
        expect(subject.errors[:email]).to include("is invalid")
      end
    end

    it "rejects a duplicate email regardless of case" do
      create(:employee, email: "asha.rao@acme.test")
      subject.email = "Asha.Rao@ACME.test"

      expect(subject).not_to be_valid
      expect(subject.errors[:email]).to include("has already been taken")
    end

    it "requires a supported country" do
      subject.country = "ZZ"

      expect(subject).not_to be_valid
      expect(subject.errors[:country]).to include("is not included in the list")
    end

    it "rejects a hire date in the future" do
      subject.hire_date = Date.current + 1

      expect(subject).not_to be_valid
      expect(subject.errors[:hire_date]).to include("can't be in the future")
    end

    it "accepts a hire date of today" do
      subject.hire_date = Date.current
      expect(subject).to be_valid
    end

    it "requires an exchange rate for the country's currency" do
      ExchangeRate.where(currency: "USD").delete_all
      employee = described_class.new(attributes_for(:employee, country: "US"))

      expect(employee).not_to be_valid
      expect(employee.errors[:exchange_rate]).to include("must exist")
    end
  end

  describe "currency" do
    it "is derived from the country" do
      employee = build(:employee, country: "IN")
      employee.validate

      expect(employee.currency).to eq("INR")
    end

    it "follows a country change" do
      employee = create(:employee, country: "US")
      create(:exchange_rate, currency: "GBP") unless ExchangeRate.exists?("GBP")

      employee.update!(country: "GB")

      expect(employee.reload.currency).to eq("GBP")
    end

    it "ignores a currency assigned directly" do
      employee = build(:employee, country: "US", currency: "INR")
      employee.validate

      expect(employee.currency).to eq("USD")
    end
  end

  describe "normalization" do
    it "downcases and strips the email" do
      expect(build(:employee, email: "  Asha.Rao@ACME.Test ").email).to eq("asha.rao@acme.test")
    end

    it "collapses whitespace in the full name" do
      expect(build(:employee, full_name: "  Asha   Rao ").full_name).to eq("Asha Rao")
    end

    it "upcases and strips the country code" do
      expect(build(:employee, country: " in ").country).to eq("IN")
    end
  end

  describe "salary precision" do
    it "stores the salary exactly with two decimal places" do
      employee = create(:employee, salary: "123456.78")
      expect(employee.reload.salary).to eq(BigDecimal("123456.78"))
    end
  end

  describe "database constraints" do
    let!(:employee) { create(:employee) }

    def insert_raw(attrs)
      row = employee.attributes.except("id", "created_at", "updated_at")
      described_class.insert_all!([ row.merge("email" => "raw@acme.test").merge(attrs) ])
    end

    it "enforces a unique email" do
      expect { insert_raw("email" => employee.email) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces a positive salary" do
      expect { insert_raw("salary" => 0) }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_salary_positive/)
    end

    it "enforces a known employment type" do
      expect { insert_raw("employment_type" => "intern") }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_employment_type_valid/)
    end

    it "enforces a two-letter uppercase country code" do
      # Raw SQL: insert_all would apply the model's upcase normalization.
      sql = described_class.sanitize_sql_array([ "UPDATE employees SET country = ? WHERE id = ?", "us", employee.id ])

      expect { described_class.connection.execute(sql) }
        .to raise_error(ActiveRecord::StatementInvalid, /employees_country_iso_3166/)
    end

    it "enforces the currency foreign key" do
      expect { insert_raw("currency" => "XXX") }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    %w[full_name email job_title department country currency salary employment_type hire_date].each do |column|
      it "requires #{column}" do
        expect { insert_raw(column => nil) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end
  end
end
