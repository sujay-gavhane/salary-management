import { screen } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { loggedInAs, loggedOut, users } from '../test/handlers.js'
import { renderApp } from '../test/render.jsx'
import { API_URL, server } from '../test/server.js'

describe('AppRoutes', () => {
  describe('when logged out', () => {
    it('sends protected pages to the login page', async () => {
      server.use(loggedOut())
      renderApp('/employees')

      expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
    })
  })

  describe('when logged in', () => {
    it('redirects the root to the employee list', async () => {
      server.use(loggedInAs(users.viewer))
      renderApp('/')

      expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
    })

    it('redirects away from the login page', async () => {
      server.use(loggedInAs(users.viewer))
      renderApp('/login')

      expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
    })

    it('shows the current user and role in the header', async () => {
      server.use(loggedInAs(users.hr_manager))
      renderApp('/employees')

      expect(await screen.findByText('Hannah HR')).toBeInTheDocument()
      expect(screen.getByText('HR Manager')).toBeInTheDocument()
    })

    it('shows the Users link only to admins', async () => {
      server.use(loggedInAs(users.admin))
      const { unmount } = renderApp('/employees')
      const adminNav = await screen.findByRole('navigation', { name: 'Main' })
      expect(adminNav).toHaveTextContent('Users')
      unmount()

      server.use(loggedInAs(users.hr_manager))
      renderApp('/employees')
      const hrNav = await screen.findByRole('navigation', { name: 'Main' })
      expect(hrNav).toHaveTextContent('Employees')
      expect(hrNav).toHaveTextContent('Insights')
      expect(hrNav).not.toHaveTextContent('Users')
    })

    it('blocks non-admins from the users page', async () => {
      server.use(loggedInAs(users.viewer))
      renderApp('/users')

      expect(await screen.findByRole('heading', { name: "You don't have access to this page" })).toBeInTheDocument()
    })

    it('lets admins open the users page', async () => {
      server.use(loggedInAs(users.admin))
      renderApp('/users')

      expect(await screen.findByRole('heading', { level: 1, name: 'Users' })).toBeInTheDocument()
    })

    it('lets HR managers create employees', async () => {
      let payload
      server.use(
        loggedInAs(users.hr_manager),
        http.post(`${API_URL}/employees`, async ({ request }) => {
          payload = await request.json()
          return HttpResponse.json(
            {
              data: {
                id: 42,
                full_name: 'Priya Nair',
                email: 'priya.nair@acme.test',
                job_title: 'Data Analyst',
                department: 'Finance',
                country: 'IN',
                currency: 'INR',
                salary: '1200000.00',
                salary_usd: '14400.00',
                employment_type: 'full_time',
                hire_date: '2024-02-20',
              },
            },
            { status: 201 },
          )
        }),
      )

      const { user } = renderApp('/employees/new')

      expect(await screen.findByRole('heading', { level: 1, name: 'Add employee' })).toBeInTheDocument()

      await user.type(screen.getByLabelText('Full name'), 'Priya Nair')
      await user.type(screen.getByLabelText('Email'), 'priya.nair@acme.test')
      await user.type(screen.getByLabelText('Job title'), 'Data Analyst')
      await user.selectOptions(screen.getByLabelText('Department'), 'Finance')
      await user.selectOptions(screen.getByLabelText('Country'), 'IN')
      await user.clear(screen.getByLabelText('Salary'))
      await user.type(screen.getByLabelText('Salary'), '1200000')
      await user.selectOptions(screen.getByLabelText('Employment type'), 'full_time')
      await user.clear(screen.getByLabelText('Hire date'))
      await user.type(screen.getByLabelText('Hire date'), '2024-02-20')
      await user.click(screen.getByRole('button', { name: 'Save employee' }))

      expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
      expect(payload).toMatchObject({
        employee: {
          full_name: 'Priya Nair',
          email: 'priya.nair@acme.test',
          job_title: 'Data Analyst',
          department: 'Finance',
          country: 'IN',
          salary: '1200000.00',
          employment_type: 'full_time',
          hire_date: '2024-02-20',
        },
      })
    })

    it('shows a not found page for unknown routes', async () => {
      server.use(loggedInAs(users.viewer))
      renderApp('/nope')

      expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument()
    })

    it('logs out and returns to the login page', async () => {
      let loggedIn = true
      server.use(
        http.get(`${API_URL}/session`, () =>
          loggedIn
            ? HttpResponse.json({ data: users.viewer })
            : HttpResponse.json({ errors: [{ code: 'unauthenticated', message: 'You need to log in' }] }, { status: 401 }),
        ),
        http.delete(`${API_URL}/session`, () => {
          loggedIn = false
          return new HttpResponse(null, { status: 204 })
        }),
      )
      const { user } = renderApp('/employees')

      await user.click(await screen.findByRole('button', { name: 'Log out' }))

      expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
      expect(loggedIn).toBe(false)
    })
  })

  describe('when the session check fails for another reason', () => {
    it('shows an error with a retry button instead of the login page', async () => {
      let calls = 0
      server.use(
        http.get(`${API_URL}/session`, () => {
          calls += 1
          return calls === 1 ? new HttpResponse(null, { status: 500 }) : HttpResponse.json({ data: users.viewer })
        }),
      )
      const { user } = renderApp('/employees')

      expect(await screen.findByRole('alert')).toHaveTextContent('Something went wrong')
      await user.click(screen.getByRole('button', { name: 'Try again' }))

      expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
    })
  })
})
