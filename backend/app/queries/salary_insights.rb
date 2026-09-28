class SalaryInsights
  RATE = "exchange_rates.rate_to_usd".freeze
  MEDIAN = "(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY employees.salary))::numeric".freeze
  SALARY_USD = "(employees.salary * #{RATE})".freeze
  AVG_USD = "ROUND(AVG#{SALARY_USD}, 2)".freeze
  BUCKET_SIZE_USD = BigDecimal("25000")

  # Each stat yields a local-currency and a USD column; USD is converted in SQL via the rate join.
  def self.money_stat(name, expression)
    { "local_#{name}": "ROUND(#{expression}, 2)", "usd_#{name}": "ROUND(#{expression} * #{RATE}, 2)" }
  end

  COUNTRY_COLUMNS = {
    country: "employees.country",
    currency: "employees.currency",
    headcount: "COUNT(*)",
    **money_stat(:min, "MIN(employees.salary)"),
    **money_stat(:max, "MAX(employees.salary)"),
    **money_stat(:avg, "AVG(employees.salary)"),
    **money_stat(:median, MEDIAN)
  }.freeze

  JOB_TITLE_COLUMNS = {
    job_title: "employees.job_title",
    headcount: "COUNT(*)",
    **money_stat(:avg, "AVG(employees.salary)")
  }.freeze

  def initialize(scope)
    @scope = scope.joins(:exchange_rate)
  end

  def by_country
    rows = @scope
      .group("employees.country", "employees.currency", RATE)
      .order("employees.country")
      .pluck(*sql(COUNTRY_COLUMNS.values))

    rows.map { |values| nest(COUNTRY_COLUMNS.keys.zip(values).to_h) }
  end

  def by_job_title(country)
    unless Country.codes.include?(country)
      raise InvalidParameterError.new(:country, "must be one of: #{Country.codes.join(', ')}")
    end

    rows = @scope
      .where(country:)
      .group("employees.job_title", RATE)
      .order(Arel.sql("AVG(employees.salary) DESC"), "employees.job_title")
      .pluck(*sql(JOB_TITLE_COLUMNS.values))

    rows.map { |values| nest(JOB_TITLE_COLUMNS.keys.zip(values).to_h) }
  end

  def rates_as_of = ExchangeRate.maximum(:as_of)

  # Cross-country figures convert each salary to USD before aggregating.
  def summary
    {
      headcount: @scope.count,
      by_country: grouped_usd(:country, :currency),
      by_department: grouped_usd(:department),
      distribution: { bucket_size_usd: BUCKET_SIZE_USD, buckets: distribution_buckets }
    }
  end

  private

  def grouped_usd(*columns)
    qualified = columns.map { |column| "employees.#{column}" }

    @scope
      .group(*qualified)
      .order(*qualified)
      .pluck(*sql(qualified + [ "COUNT(*)", AVG_USD ]))
      .map { |values| (columns + %i[headcount avg_usd]).zip(values).to_h }
  end

  def distribution_buckets
    bucket = Arel.sql("FLOOR(#{SALARY_USD} / #{BUCKET_SIZE_USD.to_i})::integer")
    counts = @scope.group(bucket).pluck(bucket, Arel.sql("COUNT(*)")).to_h
    return [] if counts.empty?

    # Fill empty bands so the histogram has no gaps.
    (0..counts.keys.max).map do |index|
      min = BUCKET_SIZE_USD * index
      { min_usd: min, max_usd: min + BUCKET_SIZE_USD, headcount: counts.fetch(index, 0) }
    end
  end

  def sql(expressions) = expressions.map { |expression| Arel.sql(expression) }

  # { local_min: 1, usd_min: 2, headcount: 3 } => { headcount: 3, local: { min: 1 }, usd: { min: 2 } }
  def nest(row)
    row.each_with_object({}) do |(key, value), shaped|
      prefix, stat = key.to_s.split("_", 2)
      if %w[local usd].include?(prefix)
        (shaped[prefix.to_sym] ||= {})[stat.to_sym] = value
      else
        shaped[key] = value
      end
    end
  end
end
