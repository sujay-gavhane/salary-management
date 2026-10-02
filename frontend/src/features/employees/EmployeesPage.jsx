import { useState } from 'react'
import { Link } from 'react-router'
import { useListEmployeesQuery } from '../../api/api.js'
import { useCan } from '../../auth/permissions.js'
import ErrorState from '../../components/ErrorState.jsx'
import LoadingState from '../../components/LoadingState.jsx'
import EmployeeTable from '../../components/EmployeeTable.jsx'

const PER_PAGE = 25
const DEFAULT_SORT = 'full_name'
const DEFAULT_DIRECTION = 'asc'

function rangeStart(page, count) {
  return count === 0 ? 0 : (page - 1) * PER_PAGE + 1
}

function rangeEnd(page, count) {
  return Math.min(page * PER_PAGE, count)
}

export default function EmployeesPage() {
  const [page, setPage] = useState(1)
  const [sort, setSort] = useState(DEFAULT_SORT)
  const [direction, setDirection] = useState(DEFAULT_DIRECTION)
  const canManageEmployees = useCan('manageEmployees')
  const { data, error, isLoading, isFetching, refetch } = useListEmployeesQuery({
    page,
    per_page: PER_PAGE,
    sort,
    direction,
  })

  function handleSort(column) {
    if (column === sort) {
      setDirection((current) => (current === 'asc' ? 'desc' : 'asc'))
    } else {
      setSort(column)
      setDirection('asc')
    }
    setPage(1)
  }

  if (isLoading) return <LoadingState label="Loading employees…" />
  if (error) return <ErrorState error={error} onRetry={refetch} />

  const employees = data?.data ?? []
  const meta = data?.meta ?? { page, total_count: 0, total_pages: 0 }
  const totalCount = meta.total_count

  return (
    <section aria-labelledby="employees-heading">
      <div className="page-heading">
        <div>
          <p className="eyebrow">PEOPLE</p>
          <h1 id="employees-heading">Employees</h1>
          <p className="page-description">Manage employee records and current compensation.</p>
        </div>
        <div className="page-actions">
          {canManageEmployees && (
            <Link to="/employees/new" className="button button--primary">
              Add employee
            </Link>
          )}
          {isFetching && <output className="refresh-indicator">Updating…</output>}
        </div>
      </div>

      {employees.length === 0 ? (
        <div className="card empty-state">
          <h2>No employees found</h2>
          <p>There are no employee records to display.</p>
        </div>
      ) : (
        <>
          <EmployeeTable employees={employees} sort={sort} direction={direction} onSort={handleSort} />
          <div className="table-footer">
            <p aria-live="polite">
              Showing {rangeStart(page, totalCount)}–{rangeEnd(page, totalCount)} of {totalCount} employees
            </p>
            <nav aria-label="Employee pages" className="pagination">
              <button
                type="button"
                className="button"
                aria-label="Previous page"
                disabled={meta.page <= 1 || isFetching}
                onClick={() => setPage((current) => Math.max(1, current - 1))}
              >
                Previous
              </button>
              <span>Page {meta.page} of {meta.total_pages}</span>
              <button
                type="button"
                className="button"
                aria-label="Next page"
                disabled={meta.page >= meta.total_pages || isFetching}
                onClick={() => setPage((current) => current + 1)}
              >
                Next
              </button>
            </nav>
          </div>
        </>
      )}
    </section>
  )
}
