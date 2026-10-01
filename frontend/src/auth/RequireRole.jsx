import PropTypes from 'prop-types'
import { Outlet } from 'react-router'
import ForbiddenPage from '../pages/ForbiddenPage.jsx'
import { useCan } from './permissions.js'

export default function RequireRole({ action }) {
  return useCan(action) ? <Outlet /> : <ForbiddenPage />
}

RequireRole.propTypes = {
  action: PropTypes.string.isRequired,
}
