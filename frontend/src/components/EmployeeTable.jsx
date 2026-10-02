import PropTypes from 'prop-types'

const COLUMNS = [
  { key: 'full_name', label: 'Full name' },
  { key: 'job_title', label: 'Job title' },
  { key: 'department', label: 'Department' },
  { key: 'country', label: 'Country' },
  { key: 'salary_usd', label: 'Salary (USD)', numeric: true },
  { key: 'hire_date', label: 'Hire date' },
]

function formatMoney(value, currency) {
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

export default function EmployeeTable({ employees, sort, direction, onSort }) {
  return (
    <div className="table-scroll">
      <table className="data-table" aria-label="Employees">
        <thead>
          <tr>
            {COLUMNS.map(({ key, label, numeric }) => (
              <th
                key={key}
                scope="col"
                aria-sort={sort === key ? (direction === 'asc' ? 'ascending' : 'descending') : 'none'}
                className={numeric ? 'data-table__numeric' : undefined}
              >
                <button
                  type="button"
                  className="table-sort"
                  aria-label={`Sort by ${label}`}
                  onClick={() => onSort(key)}
                >
                  {label}
                  <span aria-hidden="true">{sort === key ? (direction === 'asc' ? ' ▲' : ' ▼') : ''}</span>
                </button>
              </th>
            ))}
            <th scope="col">Local salary</th>
          </tr>
        </thead>
        <tbody>
          {employees.map((employee) => (
            <tr key={employee.id}>
              <th scope="row">
                <span className="employee-name">{employee.full_name}</span>
                <a className="employee-email" href={`mailto:${employee.email}`}>
                  {employee.email}
                </a>
              </th>
              <td>{employee.job_title}</td>
              <td>{employee.department}</td>
              <td>{employee.country}</td>
              <td className="data-table__numeric">{formatMoney(employee.salary_usd, 'USD')}</td>
              <td>{formatDate(employee.hire_date)}</td>
              <td>
                <span>{formatMoney(employee.salary, employee.currency)}</span>
                <span className="currency-code"> {employee.currency}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

EmployeeTable.propTypes = {
  employees: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.number.isRequired,
      full_name: PropTypes.string.isRequired,
      email: PropTypes.string.isRequired,
      job_title: PropTypes.string.isRequired,
      department: PropTypes.string.isRequired,
      country: PropTypes.string.isRequired,
      currency: PropTypes.string.isRequired,
      salary: PropTypes.string.isRequired,
      salary_usd: PropTypes.string.isRequired,
      hire_date: PropTypes.string.isRequired,
    }),
  ).isRequired,
  sort: PropTypes.string.isRequired,
  direction: PropTypes.oneOf(['asc', 'desc']).isRequired,
  onSort: PropTypes.func.isRequired,
}
