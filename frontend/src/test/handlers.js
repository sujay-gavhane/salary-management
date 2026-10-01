import { http, HttpResponse } from 'msw'
import { API_URL } from './server.js'

export const users = {
  admin: { id: 1, name: 'Ada Admin', email_address: 'admin@acme.test', role: 'admin' },
  hr_manager: { id: 2, name: 'Hannah HR', email_address: 'hr@acme.test', role: 'hr_manager' },
  viewer: { id: 3, name: 'Victor Viewer', email_address: 'viewer@acme.test', role: 'viewer' },
}

export const unauthenticated = { errors: [{ code: 'unauthenticated', message: 'You need to log in' }] }

export const loggedInAs = (user) => http.get(`${API_URL}/session`, () => HttpResponse.json({ data: user }))

export const loggedOut = () => http.get(`${API_URL}/session`, () => HttpResponse.json(unauthenticated, { status: 401 }))
