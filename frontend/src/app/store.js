import { combineReducers, configureStore } from '@reduxjs/toolkit'
import { api } from '../api/api.js'

const rootReducer = combineReducers({
  [api.reducerPath]: api.reducer,
})

export function setupStore(preloadedState) {
  return configureStore({
    reducer: rootReducer,
    middleware: (getDefaultMiddleware) => getDefaultMiddleware().concat(api.middleware),
    preloadedState,
  })
}
