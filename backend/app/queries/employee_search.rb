class EmployeeSearch
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  FILTERS = %i[country department job_title].freeze
  DIRECTIONS = %w[asc desc].freeze

  # Sort keys map to Arel nodes, so request values never reach SQL.
  SORTS = {
    "full_name" => Employee.arel_table[:full_name],
    "email" => Employee.arel_table[:email],
    "job_title" => Employee.arel_table[:job_title],
    "department" => Employee.arel_table[:department],
    "country" => Employee.arel_table[:country],
    "hire_date" => Employee.arel_table[:hire_date],
    "salary_usd" => Arel.sql("salary_usd")
  }.freeze

  SALARY_USD = Arel.sql("ROUND(employees.salary * exchange_rates.rate_to_usd, 2) AS salary_usd")

  Result = Data.define(:records, :meta)

  def initialize(scope, params)
    @scope = scope
    @params = params.to_h.symbolize_keys
  end

  def call
    page, per_page, order = self.page, self.per_page, self.order
    relation = filtered
    total_count = relation.count

    records = relation
      .joins(:exchange_rate)
      .select(Employee.arel_table[Arel.star], SALARY_USD)
      .order(order, Employee.arel_table[:id].asc)
      .limit(per_page)
      .offset((page - 1) * per_page)

    Result.new(
      records: records.to_a,
      meta: { page:, per_page:, total_count:, total_pages: (total_count + per_page - 1) / per_page }
    )
  end

  private

  def filtered
    relation = @scope
    FILTERS.each do |filter|
      relation = relation.where(filter => @params[filter]) if @params[filter].present?
    end

    query = @params[:q].to_s.strip
    return relation if query.empty?

    pattern = "%#{Employee.sanitize_sql_like(query)}%"
    relation.where("employees.full_name ILIKE :pattern OR employees.email ILIKE :pattern", pattern:)
  end

  def page = positive_integer(:page, 1)

  def per_page = [ positive_integer(:per_page, DEFAULT_PER_PAGE), MAX_PER_PAGE ].min

  def order
    sort = @params[:sort].presence || "full_name"
    direction = @params[:direction].presence || "asc"

    raise InvalidParameterError.new(:sort, "must be one of: #{SORTS.keys.join(', ')}") unless SORTS.key?(sort)
    raise InvalidParameterError.new(:direction, "must be one of: #{DIRECTIONS.join(', ')}") unless DIRECTIONS.include?(direction)

    SORTS.fetch(sort).public_send(direction)
  end

  def positive_integer(key, default)
    raw = @params[key]
    return default if raw.blank?

    value = Integer(raw.to_s, 10)
    raise ArgumentError unless value.positive?

    value
  rescue ArgumentError
    raise InvalidParameterError.new(key, "must be a positive integer")
  end
end
