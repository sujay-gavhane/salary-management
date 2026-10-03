import { NavLink, Outlet, useNavigate } from 'react-router'
import { useLogoutMutation } from '../api/api.js'
import { roleLabel, useCan, useCurrentUser } from '../auth/permissions.js'

export default function AppLayout() {
  const user = useCurrentUser()
  const canViewInsights = useCan('viewInsights')
  const canManageUsers = useCan('manageUsers')
  const [logout, { isLoading }] = useLogoutMutation()
  const navigate = useNavigate()

  async function handleLogout() {
    await logout()
    navigate('/login', { replace: true })
  }

  return (
    <>
      <header className="app-header">
        <span className="app-header__name">ACME Salary Management</span>
        <nav aria-label="Main" className="app-header__nav">
          <NavLink to="/employees">Employees</NavLink>
          {canViewInsights && <NavLink to="/insights">Insights</NavLink>}
          {canManageUsers && <NavLink to="/users">Users</NavLink>}
        </nav>
        <div className="app-header__user">
          <span>{user.name}</span>
          <span className="badge">{roleLabel(user.role)}</span>
          <button type="button" className="button" onClick={handleLogout} disabled={isLoading}>
            Log out
          </button>
        </div>
      </header>
      <main className="app">
        <Outlet />
      </main>
    </>
  )
}
