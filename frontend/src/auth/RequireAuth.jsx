import { Navigate, Outlet, useLocation } from 'react-router'
import { useGetSessionQuery } from '../api/api.js'
import ErrorState from '../components/ErrorState.jsx'
import LoadingState from '../components/LoadingState.jsx'

export default function RequireAuth() {
  const location = useLocation()
  const { data: user, error, isLoading, refetch } = useGetSessionQuery()

  if (error?.status === 401) return <Navigate to="/login" replace state={{ from: location }} />
  if (error) return <ErrorState error={error} onRetry={refetch} />
  if (isLoading || !user) return <LoadingState label="Checking your session…" />

  return <Outlet />
}
