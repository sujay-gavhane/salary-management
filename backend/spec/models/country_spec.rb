require "rails_helper"

RSpec.describe Country do
  describe ".currency_for" do
    it "maps each supported country to its currency" do
      expect(described_class.currency_for("US")).to eq("USD")
      expect(described_class.currency_for("IN")).to eq("INR")
      expect(described_class.currency_for("DE")).to eq("EUR")
      expect(described_class.currency_for("NL")).to eq("EUR")
      expect(described_class.currency_for("JP")).to eq("JPY")
    end

    it "returns nil for an unsupported country" do
      expect(described_class.currency_for("ZZ")).to be_nil
      expect(described_class.currency_for(nil)).to be_nil
    end
  end

  describe ".codes" do
    it "lists the nine supported ISO 3166-1 alpha-2 codes" do
      expect(described_class.codes).to contain_exactly("US", "GB", "DE", "NL", "CA", "IN", "SG", "JP", "AU")
    end
  end

  describe ".currencies" do
    it "lists each currency once" do
      expect(described_class.currencies).to contain_exactly("USD", "GBP", "EUR", "CAD", "INR", "SGD", "JPY", "AUD")
    end
  end
end
