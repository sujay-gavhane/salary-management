import { useState } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'
import { useGetSessionQuery, useLoginMutation } from '../api/api.js'
import { apiErrorMessage } from '../api/errors.js'
import LoadingState from '../components/LoadingState.jsx'

export default function LoginPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const { data: currentUser, isLoading: checkingSession } = useGetSessionQuery()
  const [login, { isLoading, error }] = useLoginMutation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const from = location.state?.from
  const destination = from ? `${from.pathname}${from.search ?? ''}` : '/employees'

  if (checkingSession) return <LoadingState label="Checking your session…" />
  if (currentUser) return <Navigate to={destination} replace />

  async function handleSubmit(event) {
    event.preventDefault()
    try {
      await login({ email_address: email, password }).unwrap()
      navigate(destination, { replace: true })
    } catch {
      setPassword('')
    }
  }

  return (
    <main className="login">
      <form className="card login__form" onSubmit={handleSubmit}>
        <p className="login__app-name">ACME Salary Management</p>
        <h1>Sign in</h1>

        {error && (
          <p role="alert" className="form-error">
            {apiErrorMessage(error)}
          </p>
        )}

        <div className="field">
          <label htmlFor="login-email">Email</label>
          <input
            id="login-email"
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="login-password">Password</label>
          <input
            id="login-password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
        </div>

        <button type="submit" className="button button--primary" disabled={isLoading}>
          {isLoading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  )
}
