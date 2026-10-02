import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'

export const API_URL = 'http://localhost/api/v1'

export const server = setupServer(
	http.get(`${API_URL}/employees`, () =>
		HttpResponse.json({
			data: [],
			meta: { page: 1, per_page: 25, total_count: 0, total_pages: 0 },
		}),
	),
)
