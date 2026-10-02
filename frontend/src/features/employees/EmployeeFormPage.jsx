import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import {
  useCreateEmployeeMutation,
  useGetEmployeeQuery,
  useUpdateEmployeeMutation,
} from '../../api/api.js'
import { apiErrorMessage } from '../../api/errors.js'
import ErrorState from '../../components/ErrorState.jsx'
import LoadingState from '../../components/LoadingState.jsx'

const DEPARTMENTS = [
  'Engineering',
  'Product',
  'Design',
  'Sales',
  'Marketing',
  'Finance',
  'HR',
  'Operations',
  'Support',
  'Legal',
]

const COUNTRIES = ['US', 'IN', 'GB', 'DE', 'AU', 'CA', 'SG', 'AE', 'BR', 'JP']

const EMPLOYMENT_TYPES = [
  { value: 'full_time', label: 'Full time' },
  { value: 'part_time', label: 'Part time' },
  { value: 'contract', label: 'Contract' },
]

const EMPTY_FORM = {
  full_name: '',
  email: '',
  job_title: '',
  department: '',
  country: 'US',
  salary: '',
  employment_type: 'full_time',
  hire_date: '',
}

function mapEmployeeToForm(employee) {
  if (!employee) return EMPTY_FORM

  return {
    full_name: employee.full_name ?? '',
    email: employee.email ?? '',
    job_title: employee.job_title ?? '',
    department: employee.department ?? '',
    country: employee.country ?? 'US',
    salary: employee.salary ?? '',
    employment_type: employee.employment_type ?? 'full_time',
    hire_date: employee.hire_date ?? '',
  }
}

function EmployeeForm({ initialValues, onSubmit, isEditing, isSubmitting, error }) {
  const [form, setForm] = useState(initialValues)

  function updateField(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
  }

  return (
    <form className="card" onSubmit={(event) => onSubmit(event, form)}>
      {error && <p role="alert" className="form-error">{apiErrorMessage(error)}</p>}

      <div className="field">
        <label htmlFor="employee-full-name">Full name</label>
        <input
          id="employee-full-name"
          name="full_name"
          type="text"
          required
          value={form.full_name}
          onChange={updateField}
        />
      </div>

      <div className="field">
        <label htmlFor="employee-email">Email</label>
        <input
          id="employee-email"
          name="email"
          type="email"
          required
          value={form.email}
          onChange={updateField}
        />
      </div>

      <div className="field">
        <label htmlFor="employee-job-title">Job title</label>
        <input
          id="employee-job-title"
          name="job_title"
          type="text"
          required
          value={form.job_title}
          onChange={updateField}
        />
      </div>

      <div className="field">
        <label htmlFor="employee-department">Department</label>
        <select
          id="employee-department"
          name="department"
          required
          value={form.department}
          onChange={updateField}
        >
          <option value="">Select a department</option>
          {DEPARTMENTS.map((department) => (
            <option key={department} value={department}>
              {department}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="employee-country">Country</label>
        <select
          id="employee-country"
          name="country"
          required
          value={form.country}
          onChange={updateField}
        >
          {COUNTRIES.map((country) => (
            <option key={country} value={country}>
              {country}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="employee-salary">Salary</label>
        <input
          id="employee-salary"
          name="salary"
          type="number"
          min="0"
          step="0.01"
          required
          value={form.salary}
          onChange={updateField}
        />
      </div>

      <div className="field">
        <label htmlFor="employee-employment-type">Employment type</label>
        <select
          id="employee-employment-type"
          name="employment_type"
          required
          value={form.employment_type}
          onChange={updateField}
        >
          {EMPLOYMENT_TYPES.map(({ value, label }) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label htmlFor="employee-hire-date">Hire date</label>
        <input
          id="employee-hire-date"
          name="hire_date"
          type="date"
          required
          value={form.hire_date}
          onChange={updateField}
        />
      </div>

      <button type="submit" className="button button--primary" disabled={isSubmitting}>
        {isSubmitting ? 'Saving…' : isEditing ? 'Save changes' : 'Save employee'}
      </button>
    </form>
  )
}

export default function EmployeeFormPage() {
  const navigate = useNavigate()
  const { id } = useParams()
  const isEditing = Boolean(id)

  const {
    data: employee,
    isLoading: loadingEmployee,
    error: employeeError,
    refetch: refetchEmployee,
  } = useGetEmployeeQuery(id, { skip: !isEditing })
  const [createEmployee, { isLoading: creating, error: createError }] = useCreateEmployeeMutation()
  const [updateEmployee, { isLoading: updating, error: updateError }] = useUpdateEmployeeMutation()

  async function handleSubmit(event, form) {
    event.preventDefault()

    const payload = {
      ...form,
      country: form.country.trim().toUpperCase(),
      salary: Number(form.salary || 0).toFixed(2),
    }

    try {
      if (isEditing) {
        await updateEmployee({ id, employee: payload }).unwrap()
      } else {
        await createEmployee(payload).unwrap()
      }
      navigate('/employees', { replace: true })
    } catch {
      // Error is surfaced beneath the form.
    }
  }

  if (isEditing && loadingEmployee) return <LoadingState label="Loading employee…" />
  if (isEditing && employeeError) return <ErrorState error={employeeError} onRetry={refetchEmployee} />

  const initialValues = isEditing ? mapEmployeeToForm(employee) : EMPTY_FORM
  const error = createError ?? updateError
  const isSubmitting = creating || updating

  return (
    <section>
      <div className="page-heading">
        <div>
          <p className="eyebrow">PEOPLE</p>
          <h1>{isEditing ? 'Edit employee' : 'Add employee'}</h1>
          <p className="page-description">
            {isEditing ? 'Update the selected employee record.' : 'Create a new employee profile.'}
          </p>
        </div>
        <Link to="/employees" className="button">
          Cancel
        </Link>
      </div>

      <EmployeeForm
        key={isEditing ? `employee-${id}` : 'new-employee'}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        isEditing={isEditing}
        isSubmitting={isSubmitting}
        error={error}
      />
    </section>
  )
}
