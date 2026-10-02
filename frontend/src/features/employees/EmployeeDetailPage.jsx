import { Link, useNavigate, useParams } from 'react-router'
import { useDeleteEmployeeMutation, useGetEmployeeQuery } from '../../api/api.js'
import { useCan } from '../../auth/permissions.js'
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

function formatDate(value) {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${value}T00:00:00Z`))
}

export default function EmployeeDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const canManageEmployees = useCan('manageEmployees')
  const { data, error, isLoading, refetch } = useGetEmployeeQuery(id)
  const [deleteEmployee, { isLoading: deleting }] = useDeleteEmployeeMutation()

  async function handleDelete() {
    await deleteEmployee(id).unwrap()
    navigate('/employees', { replace: true })
  }

  if (isLoading) return <LoadingState label="Loading employee…" />
  if (error) return <ErrorState error={error} onRetry={refetch} />

  const employee = data
  if (!employee) return <LoadingState label="Loading employee…" />

  return (
    <section>
      <div className="page-heading">
        <div>
          <p className="eyebrow">PEOPLE</p>
          <h1>{employee.full_name}</h1>
          <p className="page-description">Employee profile and compensation details.</p>
        </div>
        <div className="page-actions">
          <Link to="/employees" className="button">
            Back to employees
          </Link>
          {canManageEmployees && (
            <>
              <Link to={`/employees/${id}/edit`} className="button button--primary">
                Edit employee
              </Link>
              <button type="button" className="button button--danger" onClick={handleDelete} disabled={deleting}>
                {deleting ? 'Deleting…' : 'Delete employee'}
              </button>
            </>
          )}
        </div>
      </div>

      <div className="card" aria-label="Employee details">
        <dl className="detail-grid">
          <div>
            <dt>Job title</dt>
            <dd>{employee.job_title}</dd>
          </div>
          <div>
            <dt>Department</dt>
            <dd>{employee.department}</dd>
          </div>
          <div>
            <dt>Email</dt>
            <dd><a href={`mailto:${employee.email}`}>{employee.email}</a></dd>
          </div>
          <div>
            <dt>Country</dt>
            <dd>{employee.country}</dd>
          </div>
          <div>
            <dt>Employment type</dt>
            <dd>{employee.employment_type}</dd>
          </div>
          <div>
            <dt>Hire date</dt>
            <dd>{formatDate(employee.hire_date)}</dd>
          </div>
          <div>
            <dt>Salary (USD)</dt>
            <dd>{formatCurrency(employee.salary_usd, 'USD')}</dd>
          </div>
          <div>
            <dt>Local salary</dt>
            <dd>
              {formatCurrency(employee.salary, employee.currency)} {employee.currency}
            </dd>
          </div>
        </dl>
      </div>
    </section>
  )
}
