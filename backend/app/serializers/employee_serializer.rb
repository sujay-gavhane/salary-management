class EmployeeSerializer
  def initialize(employee)
    @employee = employee
  end

  def as_json(*)
    {
      id: @employee.id,
      full_name: @employee.full_name,
      email: @employee.email,
      job_title: @employee.job_title,
      department: @employee.department,
      country: @employee.country,
      currency: @employee.currency,
      salary: money(@employee.salary),
      salary_usd: money(salary_usd),
      employment_type: @employee.employment_type,
      hire_date: @employee.hire_date.iso8601
    }
  end

  private

  # List queries select salary_usd in SQL; single records fall back to the association.
  def salary_usd
    @employee.has_attribute?(:salary_usd) ? @employee[:salary_usd] : @employee.salary * @employee.exchange_rate.rate_to_usd
  end

  def money(amount)
    ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 2)
  end
end
