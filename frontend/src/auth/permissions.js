import { useGetSessionQuery } from '../api/api.js'

// Mirrors the backend Pundit policies; the API still enforces them.
const PERMISSIONS = {
  manageEmployees: ['admin', 'hr_manager'],
  viewCompensation: ['admin', 'hr_manager'],
  viewInsights: ['admin', 'hr_manager'],
  manageUsers: ['admin'],
}

const ROLE_LABELS = {
  admin: 'Admin',
  hr_manager: 'HR Manager',
  viewer: 'Viewer',
}

export const can = (user, action) => Boolean(user && PERMISSIONS[action]?.includes(user.role))

export const roleLabel = (role) => ROLE_LABELS[role] ?? role

export function useCurrentUser() {
  return useGetSessionQuery().data
}

export function useCan(action) {
  return can(useCurrentUser(), action)
}
