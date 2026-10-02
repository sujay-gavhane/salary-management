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
    listEmployees: build.query({
      query: ({ page = 1, per_page = 25, sort = 'full_name', direction = 'asc' } = {}) => ({
        url: '/employees',
        params: { page, per_page, sort, direction },
      }),
      providesTags: (result) => [
        { type: 'Employee', id: 'LIST' },
        ...(result?.data ?? []).map(({ id }) => ({ type: 'Employee', id })),
      ],
    }),
    getEmployee: build.query({
      query: (id) => `/employees/${id}`,
      transformResponse: unwrapData,
      providesTags: (result, error, id) => [{ type: 'Employee', id }],
    }),
    createEmployee: build.mutation({
      query: (employee) => ({ url: '/employees', method: 'POST', body: { employee } }),
      transformResponse: unwrapData,
      invalidatesTags: [{ type: 'Employee', id: 'LIST' }],
    }),
    updateEmployee: build.mutation({
      query: ({ id, employee }) => ({ url: `/employees/${id}`, method: 'PUT', body: { employee } }),
      transformResponse: unwrapData,
      invalidatesTags: (result, error, { id }) => [{ type: 'Employee', id }, { type: 'Employee', id: 'LIST' }],
    }),
    deleteEmployee: build.mutation({
      query: (id) => ({ url: `/employees/${id}`, method: 'DELETE' }),
      invalidatesTags: (result, error, id) => [{ type: 'Employee', id }, { type: 'Employee', id: 'LIST' }],
    }),
    listUsers: build.query({
      query: () => '/users',
      transformResponse: (response) => response.data,
      providesTags: (result) => [
        { type: 'User', id: 'LIST' },
        ...(result ?? []).map(({ id }) => ({ type: 'User', id })),
      ],
    }),
    createUser: build.mutation({
      query: (user) => ({ url: '/users', method: 'POST', body: { user } }),
      transformResponse: unwrapData,
      invalidatesTags: [{ type: 'User', id: 'LIST' }],
    }),
    updateUser: build.mutation({
      query: ({ id, user }) => ({ url: `/users/${id}`, method: 'PATCH', body: { user } }),
      transformResponse: unwrapData,
      invalidatesTags: (result, error, { id }) => [{ type: 'User', id }, { type: 'User', id: 'LIST' }],
    }),
    deleteUser: build.mutation({
      query: (id) => ({ url: `/users/${id}`, method: 'DELETE' }),
      invalidatesTags: (result, error, id) => [{ type: 'User', id }, { type: 'User', id: 'LIST' }],
    }),
    getSummary: build.query({
      query: () => '/insights/summary',
      transformResponse: (response) => response.data,
      providesTags: ['Insights'],
    }),
    getCountryInsights: build.query({
      query: () => '/insights/countries',
      transformResponse: (response) => response.data,
      providesTags: ['Insights'],
    }),
    getJobTitleInsights: build.query({
      query: (country) => ({ url: '/insights/job_titles', params: { country } }),
      transformResponse: (response) => response.data,
      providesTags: ['Insights'],
    }),
  }),
})

export const {
  useGetSessionQuery,
  useLoginMutation,
  useLogoutMutation,
  useListEmployeesQuery,
  useGetEmployeeQuery,
  useCreateEmployeeMutation,
  useUpdateEmployeeMutation,
  useDeleteEmployeeMutation,
  useListUsersQuery,
  useCreateUserMutation,
  useUpdateUserMutation,
  useDeleteUserMutation,
  useGetSummaryQuery,
  useGetCountryInsightsQuery,
  useGetJobTitleInsightsQuery,
} = api
