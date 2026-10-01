const GENERIC_MESSAGE = 'Something went wrong. Please try again.'

export function apiErrorMessage(error) {
  return error?.data?.errors?.[0]?.message ?? GENERIC_MESSAGE
}
