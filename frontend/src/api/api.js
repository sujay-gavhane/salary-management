import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react'

// 401s from these are expected (logged out, wrong password) and must not trigger a reset loop.
const SESSION_ENDPOINTS = new Set(['getSession', 'login', 'logout'])

const rawBaseQuery = fetchBaseQuery({
  baseUrl: import.meta.env.VITE_API_URL || '/api/v1',
  credentials: 'include',
})

// A 401 anywhere else means the session expired: drop every cached response, salary data included.
async function baseQuery(args, apiArg, extraOptions) {
  const result = await rawBaseQuery(args, apiArg, extraOptions)
  if (result.error?.status === 401 && !SESSION_ENDPOINTS.has(apiArg.endpoint)) {
    apiArg.dispatch(api.util.resetApiState())
  }
  return result
}

const unwrapData = (response) => response.data

export const api = createApi({
  reducerPath: 'api',
  baseQuery,
  tagTypes: ['Session', 'Employee', 'Insights', 'User'],
  endpoints: (build) => ({
    getSession: build.query({
      query: () => '/session',
      transformResponse: unwrapData,
      providesTags: ['Session'],
    }),
    login: build.mutation({
      query: (credentials) => ({ url: '/session', method: 'POST', body: credentials }),
      transformResponse: unwrapData,
      async onQueryStarted(_credentials, { dispatch, queryFulfilled }) {
        try {
          const { data: user } = await queryFulfilled
          dispatch(api.util.upsertQueryEntries([{ endpointName: 'getSession', arg: undefined, value: user }]))
        } catch {
          // The failed mutation result carries the error for the login form.
        }
      },
    }),
    logout: build.mutation({
      query: () => ({ url: '/session', method: 'DELETE' }),
      async onQueryStarted(_arg, { dispatch, queryFulfilled }) {
        try {
          await queryFulfilled
        } finally {
          dispatch(api.util.resetApiState())
        }
      },
    }),
  }),
})

export const { useGetSessionQuery, useLoginMutation, useLogoutMutation } = api
