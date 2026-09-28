import { setupListeners } from '@reduxjs/toolkit/query'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { Provider } from 'react-redux'
import './index.css'
import App from './App.jsx'
import { setupStore } from './app/store.js'

const store = setupStore()
// Refetch stale data when the tab regains focus or the network reconnects.
setupListeners(store.dispatch)

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <Provider store={store}>
      <App />
    </Provider>
  </StrictMode>,
)
