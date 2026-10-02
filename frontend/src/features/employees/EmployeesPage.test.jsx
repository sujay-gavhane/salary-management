import { screen, within } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { loggedInAs, users } from '../../test/handlers.js'
import { renderApp } from '../../test/render.jsx'
import { API_URL, server } from '../../test/server.js'

const employees = [
  {
    id: 11,
    full_name: 'Asha Rao',
    email: 'asha.rao@acme.test',
    job_title: 'Software Engineer',
    department: 'Engineering',
    country: 'IN',
    currency: 'INR',
    salary: '2400000.00',
    salary_usd: '28800.00',
    employment_type: 'full_time',
    hire_date: '2021-04-12',
  },
  {
    id: 12,
    full_name: 'Liam Chen',
    email: 'liam.chen@acme.test',
    job_title: 'Product Manager',
    department: 'Product',
    country: 'US',
    currency: 'USD',
    salary: '125000.00',
    salary_usd: '125000.00',
    employment_type: 'full_time',
    hire_date: '2022-08-01',
  },
]

const page = (data, { pageNumber = 1, perPage = 25, totalCount = data.length } = {}) => ({
  data,
  meta: {
    page: pageNumber,
    per_page: perPage,
    total_count: totalCount,
    total_pages: Math.ceil(totalCount / perPage),
  },
})

function employeeRequest(handler) {
  server.use(loggedInAs(users.viewer), http.get(`${API_URL}/employees`, handler))
}

describe('EmployeesPage', () => {
  it('shows a loading state while employees are being fetched', async () => {
    let release
    employeeRequest(() => new Promise((resolve) => {
      release = () => resolve(HttpResponse.json(page(employees)))
    }))
    renderApp('/employees')

    expect(await screen.findByText('Loading employees…')).toBeInTheDocument()
    release()
    expect(await screen.findByRole('table', { name: 'Employees' })).toBeInTheDocument()
  })

  it('renders employee fields in an accessible table', async () => {
    employeeRequest(() => HttpResponse.json(page(employees)))
    renderApp('/employees')

    const table = await screen.findByRole('table', { name: 'Employees' })
    expect(within(table).getByRole('columnheader', { name: /Full name/ })).toBeInTheDocument()
    expect(within(table).getByRole('columnheader', { name: /Salary \(USD\)/ })).toBeInTheDocument()

    const asha = within(table).getByRole('row', { name: /Asha Rao/ })
    expect(asha).toHaveTextContent('Software Engineer')
    expect(asha).toHaveTextContent('Engineering')
    expect(asha).toHaveTextContent('IN')
    expect(asha).toHaveTextContent('₹2,400,000.00')
    expect(asha).toHaveTextContent('$28,800.00')
    expect(asha).toHaveTextContent('Apr 12, 2021')
  })

  it('requests the default server-side page and sort', async () => {
    let requestUrl
    employeeRequest(({ request }) => {
      requestUrl = new URL(request.url)
      return HttpResponse.json(page(employees, { totalCount: 2 }))
    })
    renderApp('/employees')

    await screen.findByRole('table', { name: 'Employees' })

    expect(requestUrl.searchParams.get('page')).toBe('1')
    expect(requestUrl.searchParams.get('per_page')).toBe('25')
    expect(requestUrl.searchParams.get('sort')).toBe('full_name')
    expect(requestUrl.searchParams.get('direction')).toBe('asc')
  })

  it('sorts on the server and toggles the direction when the same header is pressed', async () => {
    const requests = []
    employeeRequest(({ request }) => {
      const url = new URL(request.url)
      requests.push([url.searchParams.get('sort'), url.searchParams.get('direction')])
      return HttpResponse.json(page(employees))
    })
    const { user } = renderApp('/employees')
    await screen.findByRole('table', { name: 'Employees' })

    await user.click(screen.getByRole('button', { name: 'Sort by Salary (USD)' }))
    await screen.findByRole('columnheader', { name: /Salary \(USD\)/, sort: 'ascending' })
    await user.click(screen.getByRole('button', { name: 'Sort by Salary (USD)' }))
    await screen.findByRole('columnheader', { name: /Salary \(USD\)/, sort: 'descending' })

    expect(requests).toContainEqual(['salary_usd', 'asc'])
    expect(requests).toContainEqual(['salary_usd', 'desc'])
  })

  it('paginates on the server and disables boundaries', async () => {
    const requests = []
    employeeRequest(({ request }) => {
      const requestedPage = Number(new URL(request.url).searchParams.get('page'))
      requests.push(requestedPage)
      return HttpResponse.json(page(requestedPage === 1 ? [employees[0]] : [employees[1]], {
        pageNumber: requestedPage,
        totalCount: 26,
      }))
    })
    const { user } = renderApp('/employees')

    expect(await screen.findByRole('row', { name: /Asha Rao/ })).toBeInTheDocument()
    expect(screen.getByText('Showing 1–25 of 26 employees')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Previous page' })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: 'Next page' }))

    expect(await screen.findByRole('row', { name: /Liam Chen/ })).toBeInTheDocument()
    expect(screen.getByText('Showing 26–26 of 26 employees')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Next page' })).toBeDisabled()
    expect(requests).toEqual([1, 2])
  })

  it('shows an empty state when the server returns no employees', async () => {
    employeeRequest(() => HttpResponse.json(page([], { totalCount: 0 })))
    renderApp('/employees')

    expect(await screen.findByText('No employees found')).toBeInTheDocument()
    expect(screen.queryByRole('table', { name: 'Employees' })).not.toBeInTheDocument()
  })

  it('shows an error state and retries the request', async () => {
    let requests = 0
    employeeRequest(() => {
      requests += 1
      return requests === 1
        ? HttpResponse.json({ errors: [{ code: 'internal_error', message: 'Could not load employees' }] }, { status: 500 })
        : HttpResponse.json(page(employees))
    })
    const { user } = renderApp('/employees')

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load employees')
    await user.click(screen.getByRole('button', { name: 'Try again' }))

    expect(await screen.findByRole('table', { name: 'Employees' })).toBeInTheDocument()
    expect(requests).toBe(2)
  })
})
