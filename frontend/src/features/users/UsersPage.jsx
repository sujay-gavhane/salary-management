import { useMemo, useState } from 'react'
import { useCurrentUser, roleLabel } from '../../auth/permissions.js'
import {
  useCreateUserMutation,
  useDeleteUserMutation,
  useListUsersQuery,
  useUpdateUserMutation,
} from '../../api/api.js'
import { apiErrorMessage } from '../../api/errors.js'
import ErrorState from '../../components/ErrorState.jsx'
import LoadingState from '../../components/LoadingState.jsx'

const ROLE_OPTIONS = [
  { value: 'admin', label: 'Admin' },
  { value: 'hr_manager', label: 'HR Manager' },
  { value: 'viewer', label: 'Viewer' },
]

const EMPTY_FORM = {
  name: '',
  email_address: '',
  password: '',
  role: 'viewer',
}

export default function UsersPage() {
  const currentUser = useCurrentUser()
  const [form, setForm] = useState(EMPTY_FORM)
  const [draftRoles, setDraftRoles] = useState({})
  const { data: users = [], error, isLoading, refetch } = useListUsersQuery()
  const [createUser, { isLoading: creatingUser, error: createUserError }] = useCreateUserMutation()
  const [updateUser, { isLoading: updatingUser, error: updateUserError }] = useUpdateUserMutation()
  const [deleteUser, { isLoading: deletingUser, error: deleteUserError }] = useDeleteUserMutation()

  const userById = useMemo(() => Object.fromEntries((users ?? []).map((user) => [user.id, user])), [users])

  function updateField(event) {
    const { name, value } = event.target
    setForm((current) => ({ ...current, [name]: value }))
  }

  async function handleCreateUser(event) {
    event.preventDefault()
    await createUser({ ...form }).unwrap()
    setForm(EMPTY_FORM)
  }

  async function handleRoleSave(userId) {
    const role = draftRoles[userId] ?? userById[userId]?.role
    if (!role) return
    await updateUser({ id: userId, user: { role } }).unwrap()
  }

  async function handleDeleteUser(userId) {
    if (userId === currentUser?.id) return
    await deleteUser(userId).unwrap()
  }

  if (isLoading) return <LoadingState label="Loading users…" />
  if (error) return <ErrorState error={error} onRetry={refetch} />

  return (
    <section aria-labelledby="users-heading">
      <div className="page-heading">
        <div>
          <p className="eyebrow">ACCESS</p>
          <h1 id="users-heading">Users</h1>
          <p className="page-description">Manage account access and permissions across the organization.</p>
        </div>
      </div>

      <form className="card" onSubmit={handleCreateUser}>
        <h2>Add user</h2>
        {(createUserError || updateUserError || deleteUserError) && (
          <p role="alert" className="form-error">
            {apiErrorMessage(createUserError ?? updateUserError ?? deleteUserError)}
          </p>
        )}

        <div className="field">
          <label htmlFor="user-name">Name</label>
          <input id="user-name" name="name" type="text" required value={form.name} onChange={updateField} />
        </div>

        <div className="field">
          <label htmlFor="user-email">Email</label>
          <input id="user-email" name="email_address" type="email" required value={form.email_address} onChange={updateField} />
        </div>

        <div className="field">
          <label htmlFor="user-password">Password</label>
          <input id="user-password" name="password" type="password" required value={form.password} onChange={updateField} />
        </div>

        <div className="field">
          <label htmlFor="user-role">Role</label>
          <select id="user-role" name="role" value={form.role} onChange={updateField}>
            {ROLE_OPTIONS.map(({ value, label }) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </div>

        <button type="submit" className="button button--primary" disabled={creatingUser || deletingUser || updatingUser}>
          {creatingUser ? 'Creating…' : 'Add user'}
        </button>
      </form>

      <div className="card" style={{ marginTop: '1.5rem' }}>
        <div className="table-scroll">
          <table className="data-table" aria-label="Users list">
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Email</th>
                <th scope="col">Role</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const selectedRole = draftRoles[user.id] ?? user.role
                const isSelf = user.id === currentUser?.id

                return (
                  <tr key={user.id}>
                    <th scope="row">{user.name}</th>
                    <td>{user.email_address}</td>
                    <td><span className="badge">{roleLabel(user.role)}</span></td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap' }}>
                        <select
                          value={selectedRole}
                          aria-label={`Role for ${user.name}`}
                          disabled={isSelf}
                          onChange={(event) => setDraftRoles((current) => ({ ...current, [user.id]: event.target.value }))}
                        >
                          {ROLE_OPTIONS.map(({ value, label }) => (
                            <option key={value} value={value}>
                              {label}
                            </option>
                          ))}
                        </select>
                        <button
                          type="button"
                          className="button"
                          disabled={isSelf || updatingUser || selectedRole === user.role}
                          onClick={() => handleRoleSave(user.id)}
                        >
                          Save
                        </button>
                        <button
                          type="button"
                          className="button button--danger"
                          disabled={isSelf || deletingUser}
                          onClick={() => handleDeleteUser(user.id)}
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  )
}
