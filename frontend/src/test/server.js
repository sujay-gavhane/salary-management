import { setupServer } from 'msw/node'

export const API_URL = 'http://localhost/api/v1'

export const server = setupServer()
