class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pg_trgm"

    create_table :employees do |t|
      t.string :full_name, null: false, limit: 120
      t.string :email, null: false, limit: 254
      t.string :job_title, null: false, limit: 100
      t.string :department, null: false
      t.string :country, null: false, limit: 2
      t.string :currency, null: false, limit: 3
      t.decimal :salary, precision: 12, scale: 2, null: false
      t.string :employment_type, null: false
      t.date :hire_date, null: false
      t.timestamps
    end

    add_foreign_key :employees, :exchange_rates, column: :currency, primary_key: :currency

    add_check_constraint :employees, "salary > 0", name: "employees_salary_positive"
    add_check_constraint :employees, "employment_type IN ('full_time', 'part_time', 'contract')",
      name: "employees_employment_type_valid"
    add_check_constraint :employees, "country ~ '^[A-Z]{2}$'", name: "employees_country_iso_3166"

    add_index :employees, :email, unique: true
    add_index :employees, [ :country, :job_title ]
    add_index :employees, :department
    add_index :employees, :job_title
    add_index :employees, :hire_date
    add_index :employees, :full_name, using: :gin, opclass: :gin_trgm_ops, name: "index_employees_on_full_name_trgm"
    add_index :employees, :email, using: :gin, opclass: :gin_trgm_ops, name: "index_employees_on_email_trgm"
  end
end
