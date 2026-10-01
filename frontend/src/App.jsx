import { BrowserRouter } from 'react-router'
import AppRoutes from './app/AppRoutes.jsx'

export default function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  )
}
