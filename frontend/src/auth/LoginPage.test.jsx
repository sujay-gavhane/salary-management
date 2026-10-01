import { screen } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { loggedOut, users } from '../test/handlers.js'
import { renderApp } from '../test/render.jsx'
import { API_URL, server } from '../test/server.js'

const errorResponse = (code, message, status) => HttpResponse.json({ errors: [{ code, message }] }, { status })

async function submit(user, email = 'hr@acme.test', password = 'correct-horse-battery') {
  await user.type(screen.getByLabelText('Email'), email)
  await user.type(screen.getByLabelText('Password'), password)
  await user.click(screen.getByRole('button', { name: 'Sign in' }))
}

describe('LoginPage', () => {
  it('has labelled email and password fields with autocomplete hints', async () => {
    server.use(loggedOut())
    renderApp('/login')

    expect(await screen.findByLabelText('Email')).toHaveAttribute('autocomplete', 'username')
    expect(screen.getByLabelText('Password')).toHaveAttribute('type', 'password')
    expect(screen.getByLabelText('Password')).toHaveAttribute('autocomplete', 'current-password')
  })

  it('signs in and returns to the page that was originally requested', async () => {
    let body
    server.use(
      loggedOut(),
      http.post(`${API_URL}/session`, async ({ request }) => {
        body = await request.json()
        return HttpResponse.json({ data: users.hr_manager }, { status: 201 })
      }),
    )
    const { user } = renderApp('/insights')
    await screen.findByRole('heading', { name: 'Sign in' })

    await submit(user)

    expect(await screen.findByRole('heading', { level: 1, name: 'Insights' })).toBeInTheDocument()
    expect(body).toEqual({ email_address: 'hr@acme.test', password: 'correct-horse-battery' })
  })

  it('goes to the employee list when no page was requested', async () => {
    server.use(loggedOut(), http.post(`${API_URL}/session`, () => HttpResponse.json({ data: users.viewer }, { status: 201 })))
    const { user } = renderApp('/login')
    await screen.findByRole('heading', { name: 'Sign in' })

    await submit(user)

    expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
  })

  it('shows the API error for invalid credentials and keeps the email', async () => {
    server.use(loggedOut(), http.post(`${API_URL}/session`, () => errorResponse('invalid_credentials', 'Invalid email or password', 401)))
    const { user } = renderApp('/login')
    await screen.findByRole('heading', { name: 'Sign in' })

    await submit(user, 'hr@acme.test', 'wrong-password')

    expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email or password')
    expect(screen.getByLabelText('Email')).toHaveValue('hr@acme.test')
    expect(screen.getByLabelText('Password')).toHaveValue('')
  })

  it('shows the rate-limit message', async () => {
    server.use(
      loggedOut(),
      http.post(`${API_URL}/session`, () => errorResponse('rate_limited', 'Too many login attempts. Try again later.', 429)),
    )
    const { user } = renderApp('/login')
    await screen.findByRole('heading', { name: 'Sign in' })

    await submit(user)

    expect(await screen.findByRole('alert')).toHaveTextContent('Too many login attempts. Try again later.')
  })

  it('disables the button while signing in', async () => {
    let release
    server.use(
      loggedOut(),
      http.post(`${API_URL}/session`, () => new Promise((resolve) => {
        release = () => resolve(HttpResponse.json({ data: users.viewer }, { status: 201 }))
      })),
    )
    const { user } = renderApp('/login')
    await screen.findByRole('heading', { name: 'Sign in' })

    await submit(user)

    expect(await screen.findByRole('button', { name: 'Signing in…' })).toBeDisabled()
    release()
    expect(await screen.findByRole('heading', { level: 1, name: 'Employees' })).toBeInTheDocument()
  })
})
