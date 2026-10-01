import { render } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Provider } from 'react-redux'
import { MemoryRouter } from 'react-router'
import AppRoutes from '../app/AppRoutes.jsx'
import { setupStore } from '../app/store.js'

export function renderApp(route = '/', { store = setupStore() } = {}) {
  const user = userEvent.setup()
  const utils = render(
    <Provider store={store}>
      <MemoryRouter initialEntries={[route]}>
        <AppRoutes />
      </MemoryRouter>
    </Provider>,
  )
  return { ...utils, store, user }
}
