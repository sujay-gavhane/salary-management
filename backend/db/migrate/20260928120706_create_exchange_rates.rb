class CreateExchangeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :exchange_rates, id: false do |t|
      t.string :currency, limit: 3, null: false, primary_key: true
      t.decimal :rate_to_usd, precision: 18, scale: 8, null: false
      t.date :as_of, null: false
      t.timestamps
    end

    add_check_constraint :exchange_rates, "rate_to_usd > 0", name: "exchange_rates_rate_to_usd_positive"
    add_check_constraint :exchange_rates, "currency ~ '^[A-Z]{3}$'", name: "exchange_rates_currency_iso_4217"
  end
end
