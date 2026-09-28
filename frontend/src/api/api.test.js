import { http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { setupStore } from '../app/store.js'
import { API_URL, server } from '../test/server.js'
import { api } from './api.js'

const user = { id: 1, name: 'Hannah HR', email_address: 'hr@acme.test', role: 'hr_manager' }
const unauthenticated = { errors: [{ code: 'unauthenticated', message: 'You need to log in' }] }

// A data endpoint standing in for the feature endpoints injected later.
const probeApi = api.injectEndpoints({
  endpoints: (build) => ({ probe: build.query({ query: () => '/probe' }) }),
})

describe('api', () => {
  let store

  beforeEach(() => {
    store = setupStore()
  })

  describe('getSession', () => {
    it('fetches the current user and sends the session cookie', async () => {
      let credentials
      server.use(
        http.get(`${API_URL}/session`, ({ request }) => {
          credentials = request.credentials
          return HttpResponse.json({ data: user })
        }),
      )

      const result = await store.dispatch(api.endpoints.getSession.initiate())

      expect(result.data).toEqual(user)
      expect(credentials).toBe('include')
    })

    it('reports 401 without resetting the API state, so it cannot loop', async () => {
      server.use(
        http.get(`${API_URL}/probe`, () => HttpResponse.json({ ok: true })),
        http.get(`${API_URL}/session`, () => HttpResponse.json(unauthenticated, { status: 401 })),
      )
      await store.dispatch(probeApi.endpoints.probe.initiate(undefined))

      const result = await store.dispatch(api.endpoints.getSession.initiate())

      expect(result.error.status).toBe(401)
      expect(probeApi.endpoints.probe.select(undefined)(store.getState()).data).toEqual({ ok: true })
    })
  })

  describe('login', () => {
    it('posts JSON credentials and caches the returned user as the session', async () => {
      let body
      let contentType
      server.use(
        http.post(`${API_URL}/session`, async ({ request }) => {
          body = await request.json()
          contentType = request.headers.get('Content-Type')
          return HttpResponse.json({ data: user }, { status: 201 })
        }),
      )

      await store.dispatch(api.endpoints.login.initiate({ email_address: 'hr@acme.test', password: 'secret-password' }))

      expect(body).toEqual({ email_address: 'hr@acme.test', password: 'secret-password' })
      expect(contentType).toBe('application/json')
      await vi.waitFor(() => expect(api.endpoints.getSession.select()(store.getState()).data).toEqual(user))
    })

    it('surfaces invalid credentials as an error without resetting the API state', async () => {
      server.use(
        http.post(`${API_URL}/session`, () =>
          HttpResponse.json({ errors: [{ code: 'invalid_credentials', message: 'Invalid email or password' }] }, { status: 401 }),
        ),
        http.get(`${API_URL}/probe`, () => HttpResponse.json({ ok: true })),
      )
      await store.dispatch(probeApi.endpoints.probe.initiate(undefined))

      const result = await store.dispatch(api.endpoints.login.initiate({ email_address: 'x@acme.test', password: 'wrong' }))

      expect(result.error.data.errors[0].code).toBe('invalid_credentials')
      expect(probeApi.endpoints.probe.select(undefined)(store.getState()).data).toEqual({ ok: true })
    })
  })

  describe('logout', () => {
    it('deletes the session and clears all cached data', async () => {
      let deleted = false
      server.use(
        http.get(`${API_URL}/probe`, () => HttpResponse.json({ salary: '100000.00' })),
        http.delete(`${API_URL}/session`, () => {
          deleted = true
          return new HttpResponse(null, { status: 204 })
        }),
      )
      await store.dispatch(probeApi.endpoints.probe.initiate(undefined))

      await store.dispatch(api.endpoints.logout.initiate())

      expect(deleted).toBe(true)
      expect(store.getState().api.queries).toEqual({})
    })
  })

  describe('401 from a data endpoint', () => {
    it('clears all cached data so an expired session cannot keep showing salaries', async () => {
      server.use(
        http.get(`${API_URL}/session`, () => HttpResponse.json({ data: user })),
        http.get(`${API_URL}/probe`, () => HttpResponse.json(unauthenticated, { status: 401 })),
      )
      await store.dispatch(api.endpoints.getSession.initiate())

      await store.dispatch(probeApi.endpoints.probe.initiate(undefined))

      expect(api.endpoints.getSession.select()(store.getState()).data).toBeUndefined()
    })

    it('leaves the cache alone for other errors', async () => {
      server.use(
        http.get(`${API_URL}/session`, () => HttpResponse.json({ data: user })),
        http.get(`${API_URL}/probe`, () => HttpResponse.json({ errors: [] }, { status: 403 })),
      )
      await store.dispatch(api.endpoints.getSession.initiate())

      await store.dispatch(probeApi.endpoints.probe.initiate(undefined))

      expect(api.endpoints.getSession.select()(store.getState()).data).toEqual(user)
    })
  })
})
