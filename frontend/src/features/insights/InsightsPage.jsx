import { useMemo, useState } from 'react'
import { useGetCountryInsightsQuery, useGetJobTitleInsightsQuery, useGetSummaryQuery } from '../../api/api.js'
import ErrorState from '../../components/ErrorState.jsx'
import LoadingState from '../../components/LoadingState.jsx'

function formatCurrency(value, currency) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(value))
}

export default function InsightsPage() {
  const [selectedCountry, setSelectedCountry] = useState('')
  const {
    data: summary,
    error: summaryError,
    isLoading: loadingSummary,
    refetch: refetchSummary,
  } = useGetSummaryQuery()
  const {
    data: countries,
    error: countriesError,
    isLoading: loadingCountries,
    refetch: refetchCountries,
  } = useGetCountryInsightsQuery()
  const effectiveCountry = useMemo(
    () => selectedCountry || countries?.[0]?.country || '',
    [countries, selectedCountry],
  )

  const {
    data: jobTitles,
    error: jobTitlesError,
    isLoading: loadingJobTitles,
    refetch: refetchJobTitles,
  } = useGetJobTitleInsightsQuery(effectiveCountry, { skip: !effectiveCountry })

  const averageSalary = useMemo(() => {
    if (!summary?.by_country?.length) return '$0.00'
    const total = summary.by_country.reduce((sum, row) => sum + Number(row.avg_usd || 0), 0)
    return formatCurrency(total / summary.by_country.length, 'USD')
  }, [summary])

  if (loadingSummary || loadingCountries) return <LoadingState label="Loading insights…" />
  if (summaryError) return <ErrorState error={summaryError} onRetry={refetchSummary} />
  if (countriesError) return <ErrorState error={countriesError} onRetry={refetchCountries} />
  if (jobTitlesError && selectedCountry) return <ErrorState error={jobTitlesError} onRetry={refetchJobTitles} />

  const countryOptions = countries ?? []

  return (
    <section>
      <div className="page-heading">
        <div>
          <p className="eyebrow">OVERVIEW</p>
          <h1>Insights</h1>
        </div>
      </div>

      <div className="summary-grid">
        <article className="card metric-card">
          <p className="metric-label">Company headcount</p>
          <strong className="metric-value">{summary?.headcount ?? 0}</strong>
        </article>
        <article className="card metric-card">
          <p className="metric-label">Average salary</p>
          <strong className="metric-value">{averageSalary}</strong>
        </article>
        <article className="card metric-card">
          <p className="metric-label">Countries tracked</p>
          <strong className="metric-value">{countryOptions.length}</strong>
        </article>
      </div>

      <div className="card insights-panel">
        <h2>Country overview</h2>
        <div className="table-scroll">
          <table className="data-table" aria-label="Country overview">
            <thead>
              <tr>
                <th scope="col">Country</th>
                <th scope="col">Headcount</th>
                <th scope="col">Avg salary (USD)</th>
                <th scope="col">Local avg</th>
              </tr>
            </thead>
            <tbody>
              {(countryOptions.length === 0 ? [] : countryOptions).map((country) => (
                <tr key={country.country}>
                  <th scope="row">{country.country}</th>
                  <td>{country.headcount}</td>
                  <td>{formatCurrency(country.usd.avg, 'USD')}</td>
                  <td>{formatCurrency(country.local.avg, country.currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card insights-panel">
        <div className="insights-toolbar">
          <h2>Job title by country</h2>
          <div className="field field--inline">
            <label htmlFor="insights-country">Country</label>
            <select id="insights-country" value={effectiveCountry} onChange={(event) => setSelectedCountry(event.target.value)}>
              {countryOptions.map((country) => (
                <option key={country.country} value={country.country}>
                  {country.country}
                </option>
              ))}
            </select>
          </div>
        </div>

        {loadingJobTitles ? (
          <LoadingState label="Loading country insights…" />
        ) : (
          <div className="table-scroll">
            <table className="data-table" aria-label="Job title insights">
              <thead>
                <tr>
                  <th scope="col">Job title</th>
                  <th scope="col">Headcount</th>
                  <th scope="col">Avg salary (USD)</th>
                  <th scope="col">Avg local salary</th>
                </tr>
              </thead>
              <tbody>
                {(jobTitles ?? []).map((role) => (
                  <tr key={role.job_title}>
                    <th scope="row">
                      <h2>{role.job_title}</h2>
                    </th>
                    <td>{role.headcount}</td>
                    <td>{formatCurrency(role.usd.avg, 'USD')}</td>
                    <td>{formatCurrency(role.local.avg, effectiveCountry === 'IN' ? 'INR' : 'USD')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </section>
  )
}
