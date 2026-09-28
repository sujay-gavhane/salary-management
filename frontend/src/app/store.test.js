import { describe, expect, it } from 'vitest'
import { api } from '../api/api.js'
import { setupStore } from './store.js'

describe('setupStore', () => {
  it('mounts the RTK Query cache', () => {
    expect(setupStore().getState()).toHaveProperty(api.reducerPath)
  })

  it('creates an independent store each time', () => {
    expect(setupStore()).not.toBe(setupStore())
  })
})
