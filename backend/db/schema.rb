# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_28_121445) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "employees", force: :cascade do |t|
    t.string "full_name", limit: 120, null: false
    t.string "email", limit: 254, null: false
    t.string "job_title", limit: 100, null: false
    t.string "department", null: false
    t.string "country", limit: 2, null: false
    t.string "currency", limit: 3, null: false
    t.decimal "salary", precision: 12, scale: 2, null: false
    t.string "employment_type", null: false
    t.date "hire_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country", "job_title"], name: "index_employees_on_country_and_job_title"
    t.index ["department"], name: "index_employees_on_department"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["email"], name: "index_employees_on_email_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["full_name"], name: "index_employees_on_full_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["hire_date"], name: "index_employees_on_hire_date"
    t.index ["job_title"], name: "index_employees_on_job_title"
    t.check_constraint "country::text ~ '^[A-Z]{2}$'::text", name: "employees_country_iso_3166"
    t.check_constraint "employment_type::text = ANY (ARRAY['full_time'::character varying, 'part_time'::character varying, 'contract'::character varying]::text[])", name: "employees_employment_type_valid"
    t.check_constraint "salary > 0::numeric", name: "employees_salary_positive"
  end

  create_table "exchange_rates", primary_key: "currency", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.decimal "rate_to_usd", precision: 18, scale: 8, null: false
    t.date "as_of", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "exchange_rates_currency_iso_4217"
    t.check_constraint "rate_to_usd > 0::numeric", name: "exchange_rates_rate_to_usd_positive"
  end

  add_foreign_key "employees", "exchange_rates", column: "currency", primary_key: "currency"
end
