require "rails_helper"

RSpec.describe EmployeeSearch do
  def search(params = {})
    described_class.new(Employee.all, params).call
  end

  def names(result) = result.records.map(&:full_name)

  before do
    create(:exchange_rate, currency: "USD", rate_to_usd: "1")
    create(:exchange_rate, currency: "INR", rate_to_usd: "0.012")
    create(:exchange_rate, currency: "GBP", rate_to_usd: "1.27")
  end

  describe "defaults" do
    it "sorts by full name ascending and returns 25 per page" do
      create_list(:employee, 30)
      result = search

      expect(result.records.size).to eq(25)
      expect(names(result)).to eq(names(result).sort)
      expect(result.meta).to eq(page: 1, per_page: 25, total_count: 30, total_pages: 2)
    end

    it "selects salary_usd computed in SQL, rounded to 2 decimals" do
      create(:employee, country: "IN", salary: "1234567.89")
      expect(search.records.first[:salary_usd]).to eq(BigDecimal("14814.81"))
    end
  end

  describe "pagination" do
    before { create_list(:employee, 7) }

    it "returns the requested page" do
      result = search(page: "2", per_page: "3")

      expect(result.records.size).to eq(3)
      expect(result.meta).to eq(page: 2, per_page: 3, total_count: 7, total_pages: 3)
    end

    it "returns an empty page beyond the last one" do
      result = search(page: "99", per_page: "3")

      expect(result.records).to be_empty
      expect(result.meta[:total_count]).to eq(7)
    end

    it "caps per_page at 100" do
      expect(search(per_page: "5000").meta[:per_page]).to eq(100)
    end

    it "rejects a non-positive or non-numeric page or per_page" do
      [ { page: "0" }, { page: "-1" }, { page: "abc" }, { per_page: "0" }, { per_page: "1.5" } ].each do |params|
        expect { search(params) }.to raise_error(InvalidParameterError), "expected #{params} to be rejected"
      end
    end

    it "keeps a stable order across pages when sort values tie" do
      Employee.update_all(department: "Engineering")
      page_one = search(sort: "department", per_page: "4", page: "1").records.map(&:id)
      page_two = search(sort: "department", per_page: "4", page: "2").records.map(&:id)

      expect(page_one + page_two).to eq(Employee.order(:id).pluck(:id))
    end
  end

  describe "search" do
    before do
      create(:employee, full_name: "Asha Rao", email: "asha.rao@acme.test")
      create(:employee, full_name: "Liam Chen", email: "l.chen@acme.test")
      create(:employee, full_name: "Maria Garcia", email: "mgarcia_rao@acme.test")
    end

    it "matches a case-insensitive substring of the name or email" do
      expect(names(search(q: "RAO"))).to contain_exactly("Asha Rao", "Maria Garcia")
      expect(names(search(q: "chen@"))).to contain_exactly("Liam Chen")
    end

    it "ignores surrounding whitespace and blank queries" do
      expect(names(search(q: "  liam "))).to eq([ "Liam Chen" ])
      expect(search(q: "   ").meta[:total_count]).to eq(3)
    end

    it "treats LIKE wildcards literally" do
      expect(search(q: "%").records).to be_empty
      expect(names(search(q: "_rao"))).to eq([ "Maria Garcia" ])
    end
  end

  describe "filters" do
    before do
      create(:employee, full_name: "Aa", country: "IN", department: "Engineering", job_title: "Software Engineer")
      create(:employee, full_name: "Bb", country: "IN", department: "Sales", job_title: "Account Executive")
      create(:employee, full_name: "Cc", country: "GB", department: "Engineering", job_title: "Software Engineer")
    end

    it "filters by exact country, department, and job title" do
      expect(names(search(country: "IN"))).to eq(%w[Aa Bb])
      expect(names(search(department: "Engineering"))).to eq(%w[Aa Cc])
      expect(names(search(job_title: "Account Executive"))).to eq(%w[Bb])
    end

    it "combines filters and search with AND" do
      expect(names(search(country: "IN", department: "Engineering"))).to eq(%w[Aa])
      expect(names(search(country: "GB", q: "aa"))).to be_empty
    end

    it "returns nothing for an unknown filter value instead of failing" do
      expect(search(country: "ZZ").records).to be_empty
    end
  end

  describe "sorting" do
    before do
      create(:employee, full_name: "India High", country: "IN", salary: "5000000", hire_date: Date.new(2020, 1, 1))
      create(:employee, full_name: "US Mid", country: "US", salary: "50000", hire_date: Date.new(2022, 1, 1))
      create(:employee, full_name: "UK Top", country: "GB", salary: "90000", hire_date: Date.new(2021, 1, 1))
    end

    it "sorts salary by its USD value, not the local amount" do
      # USD: India 60,000; US 50,000; UK 114,300
      expect(names(search(sort: "salary_usd", direction: "desc"))).to eq([ "UK Top", "India High", "US Mid" ])
      expect(names(search(sort: "salary_usd", direction: "asc"))).to eq([ "US Mid", "India High", "UK Top" ])
    end

    it "sorts by any whitelisted column in either direction" do
      expect(names(search(sort: "hire_date"))).to eq([ "India High", "UK Top", "US Mid" ])
      expect(names(search(sort: "country", direction: "desc"))).to eq([ "US Mid", "India High", "UK Top" ])
    end

    it "accepts every documented sort key" do
      EmployeeSearch::SORTS.each_key do |key|
        expect { search(sort: key) }.not_to raise_error
      end
      expect(EmployeeSearch::SORTS.keys).to contain_exactly(
        "full_name", "email", "job_title", "department", "country", "hire_date", "salary_usd"
      )
    end

    it "rejects a sort key outside the whitelist" do
      [ "salary; DROP TABLE employees", "password_digest", "id" ].each do |key|
        expect { search(sort: key) }.to raise_error(InvalidParameterError, /sort/)
      end
    end

    it "rejects an unknown direction" do
      expect { search(direction: "sideways") }.to raise_error(InvalidParameterError, /direction/)
    end
  end
end
