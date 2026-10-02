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
	http.get(`${API_URL}/insights/summary`, () =>
		HttpResponse.json({
			data: {
				headcount: 0,
				by_country: [],
				by_department: [],
				distribution: { bucket_size_usd: '25000.00', buckets: [] },
			},
			rates_as_of: '2026-09-01',
		}),
	),
	http.get(`${API_URL}/insights/countries`, () =>
		HttpResponse.json({
			data: [],
			rates_as_of: '2026-09-01',
		}),
	),
	http.get(`${API_URL}/insights/job_titles`, () =>
		HttpResponse.json({
			data: [],
			rates_as_of: '2026-09-01',
		}),
	),
	http.get(`${API_URL}/users`, () =>
		HttpResponse.json({
			data: [],
		}),
	),
)
