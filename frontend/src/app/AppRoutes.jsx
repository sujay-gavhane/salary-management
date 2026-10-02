import { Navigate, Route, Routes } from 'react-router'
import LoginPage from '../auth/LoginPage.jsx'
import RequireAuth from '../auth/RequireAuth.jsx'
import RequireRole from '../auth/RequireRole.jsx'
import EmployeeFormPage from '../features/employees/EmployeeFormPage.jsx'
import EmployeesPage from '../features/employees/EmployeesPage.jsx'
import InsightsPage from '../features/insights/InsightsPage.jsx'
import UsersPage from '../features/users/UsersPage.jsx'
import AppLayout from '../layout/AppLayout.jsx'
import NotFoundPage from '../pages/NotFoundPage.jsx'

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route element={<AppLayout />}>
          <Route index element={<Navigate to="/employees" replace />} />
          <Route path="employees" element={<EmployeesPage />} />
          <Route element={<RequireRole action="manageEmployees" />}>
            <Route path="employees/new" element={<EmployeeFormPage />} />
            <Route path="employees/:id/edit" element={<EmployeeFormPage />} />
          </Route>
          <Route path="insights" element={<InsightsPage />} />
          <Route element={<RequireRole action="manageUsers" />}>
            <Route path="users" element={<UsersPage />} />
          </Route>
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  )
}
