class EmployeeSerializer
  def initialize(employee)
    @employee = employee
  end

  def as_json(*)
    base = {
      id: @employee.id,
      full_name: @employee.full_name,
      email: @employee.email,
      job_title: @employee.job_title,
      department: @employee.department,
      country: @employee.country,
      currency: @employee.currency,
      employment_type: @employee.employment_type,
      hire_date: @employee.hire_date.iso8601
    }

    if Current.user&.viewer?
      base
    else
      base.merge(
        salary: MoneyFormat.call(@employee.salary),
        salary_usd: MoneyFormat.call(salary_usd)
      )
    end
  end

  private

  # List queries select salary_usd in SQL; single records fall back to the association.
  def salary_usd
    @employee.has_attribute?(:salary_usd) ? @employee[:salary_usd] : @employee.salary * @employee.exchange_rate.rate_to_usd
  end
end
