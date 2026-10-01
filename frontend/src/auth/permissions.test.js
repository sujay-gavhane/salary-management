import { describe, expect, it } from 'vitest'
import { users } from '../test/handlers.js'
import { can, roleLabel } from './permissions.js'

describe('can', () => {
  it('lets admins and HR managers manage employees, but not viewers', () => {
    expect(can(users.admin, 'manageEmployees')).toBe(true)
    expect(can(users.hr_manager, 'manageEmployees')).toBe(true)
    expect(can(users.viewer, 'manageEmployees')).toBe(false)
  })

  it('lets only admins manage users', () => {
    expect(can(users.admin, 'manageUsers')).toBe(true)
    expect(can(users.hr_manager, 'manageUsers')).toBe(false)
    expect(can(users.viewer, 'manageUsers')).toBe(false)
  })

  it('denies everything without a user or for an unknown action', () => {
    expect(can(undefined, 'manageEmployees')).toBe(false)
    expect(can(users.admin, 'launchRockets')).toBe(false)
  })
})

describe('roleLabel', () => {
  it('returns a readable label for each role', () => {
    expect(roleLabel('admin')).toBe('Admin')
    expect(roleLabel('hr_manager')).toBe('HR Manager')
    expect(roleLabel('viewer')).toBe('Viewer')
  })
})
