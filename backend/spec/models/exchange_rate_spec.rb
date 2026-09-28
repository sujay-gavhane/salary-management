require "rails_helper"

RSpec.describe ExchangeRate, type: :model do
  describe "validations" do
    subject { build(:exchange_rate) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:rate_to_usd) }
    it { is_expected.to validate_numericality_of(:rate_to_usd).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:as_of) }

    it "rejects currency codes that are not three letters" do
      %w[US USDX U1D].each do |code|
        subject.currency = code
        expect(subject).not_to be_valid, "expected #{code} to be invalid"
      end
    end

    it "rejects a duplicate currency regardless of case" do
      create(:exchange_rate, currency: "EUR")
      subject.currency = "eur"

      expect(subject).not_to be_valid
      expect(subject.errors[:currency]).to include("has already been taken")
    end
  end

  describe "normalization" do
    it "upcases and strips the currency code" do
      expect(build(:exchange_rate, currency: " inr ").currency).to eq("INR")
    end
  end

  describe "database constraints" do
    let(:valid_attributes) { { currency: "GBP", rate_to_usd: 1.27, as_of: Date.new(2026, 9, 1) } }

    def insert_raw(attrs)
      described_class.insert_all!([ valid_attributes.merge(attrs) ])
    end

    it "uses the currency code as the primary key" do
      expect(described_class.primary_key).to eq("currency")
    end

    it "enforces a unique currency" do
      insert_raw({})
      expect { insert_raw({}) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces a positive rate" do
      expect { insert_raw(rate_to_usd: 0) }
        .to raise_error(ActiveRecord::StatementInvalid, /exchange_rates_rate_to_usd_positive/)
    end

    it "enforces a three-letter uppercase currency code" do
      expect { insert_raw(currency: "gb") }
        .to raise_error(ActiveRecord::StatementInvalid, /exchange_rates_currency_iso_4217/)
    end

    it "requires as_of" do
      expect { insert_raw(as_of: nil) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "stores rates with 8 decimal places" do
      insert_raw(rate_to_usd: "0.00675432")
      expect(described_class.find("GBP").rate_to_usd).to eq(BigDecimal("0.00675432"))
    end
  end
end
