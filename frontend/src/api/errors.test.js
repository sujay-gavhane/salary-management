import { describe, expect, it } from 'vitest'
import { apiErrorMessage } from './errors.js'

describe('apiErrorMessage', () => {
  it('returns the first API error message', () => {
    const error = { status: 401, data: { errors: [{ code: 'invalid_credentials', message: 'Invalid email or password' }] } }
    expect(apiErrorMessage(error)).toBe('Invalid email or password')
  })

  it('falls back to a generic message for network or unexpected errors', () => {
    expect(apiErrorMessage({ status: 'FETCH_ERROR', error: 'TypeError: Failed to fetch' })).toBe(
      'Something went wrong. Please try again.',
    )
    expect(apiErrorMessage({ status: 500, data: '<html>' })).toBe('Something went wrong. Please try again.')
    expect(apiErrorMessage(undefined)).toBe('Something went wrong. Please try again.')
  })
})
