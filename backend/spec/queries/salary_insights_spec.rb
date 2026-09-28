require "rails_helper"

RSpec.describe SalaryInsights do
  subject(:insights) { described_class.new(Employee.all) }

  before do
    create(:exchange_rate, currency: "USD", rate_to_usd: "1", as_of: Date.new(2026, 8, 1))
    create(:exchange_rate, currency: "INR", rate_to_usd: "0.012", as_of: Date.new(2026, 9, 1))
    create(:exchange_rate, currency: "GBP", rate_to_usd: "1.27", as_of: Date.new(2026, 9, 1))

    create(:employee, country: "IN", job_title: "Engineer", salary: "1000000")
    create(:employee, country: "IN", job_title: "Engineer", salary: "2000000")
    create(:employee, country: "IN", job_title: "Manager", salary: "6000000")
    create(:employee, country: "US", job_title: "Engineer", salary: "50000")
    create(:employee, country: "US", job_title: "Engineer", salary: "70000")
  end

  describe "#by_country" do
    it "returns headcount and min/max/avg/median in local currency and USD, one row per country" do
      expect(insights.by_country).to eq([
        {
          country: "IN", currency: "INR", headcount: 3,
          local: { min: BigDecimal("1000000"), max: BigDecimal("6000000"), avg: BigDecimal("3000000"), median: BigDecimal("2000000") },
          usd: { min: BigDecimal("12000"), max: BigDecimal("72000"), avg: BigDecimal("36000"), median: BigDecimal("24000") }
        },
        {
          country: "US", currency: "USD", headcount: 2,
          local: { min: BigDecimal("50000"), max: BigDecimal("70000"), avg: BigDecimal("60000"), median: BigDecimal("60000") },
          usd: { min: BigDecimal("50000"), max: BigDecimal("70000"), avg: BigDecimal("60000"), median: BigDecimal("60000") }
        }
      ])
    end

    it "averages the two middle values for the median of an even-sized group" do
      create(:employee, country: "IN", salary: "3000000")
      india = insights.by_country.find { |row| row[:country] == "IN" }

      expect(india[:local][:median]).to eq(BigDecimal("2500000"))
      expect(india[:usd][:median]).to eq(BigDecimal("30000"))
    end

    it "rounds averages to 2 decimal places" do
      Employee.delete_all
      [ "1", "1", "2" ].each { |salary| create(:employee, country: "US", salary:) }

      expect(insights.by_country.first[:local][:avg]).to eq(BigDecimal("1.33"))
    end

    it "omits countries without employees" do
      expect(insights.by_country.map { |row| row[:country] }).not_to include("GB")
    end

    it "runs a single SQL query" do
      expect(count_queries { insights.by_country }).to eq(1)
    end
  end

  describe "#by_job_title" do
    it "returns headcount and average salary per job title in the country, highest average first" do
      expect(insights.by_job_title("IN")).to eq([
        { job_title: "Manager", headcount: 1, local: { avg: BigDecimal("6000000") }, usd: { avg: BigDecimal("72000") } },
        { job_title: "Engineer", headcount: 2, local: { avg: BigDecimal("1500000") }, usd: { avg: BigDecimal("18000") } }
      ])
    end

    it "only includes employees in the requested country" do
      expect(insights.by_job_title("US")).to eq([
        { job_title: "Engineer", headcount: 2, local: { avg: BigDecimal("60000") }, usd: { avg: BigDecimal("60000") } }
      ])
    end

    it "returns an empty list for a supported country without employees" do
      expect(insights.by_job_title("GB")).to eq([])
    end

    it "rejects a missing or unsupported country" do
      [ nil, "", "ZZ", "in" ].each do |country|
        expect { insights.by_job_title(country) }.to raise_error(InvalidParameterError, /country/)
      end
    end

    it "runs a single SQL query" do
      expect(count_queries { insights.by_job_title("IN") }).to eq(1)
    end
  end

  describe "#rates_as_of" do
    it "returns the most recent exchange-rate date" do
      expect(insights.rates_as_of).to eq(Date.new(2026, 9, 1))
    end
  end
end
