import { Link } from 'react-router'

export default function ForbiddenPage() {
  return (
    <section>
      <h1>You don&apos;t have access to this page</h1>
      <p>Ask an admin if you need access.</p>
      <Link to="/employees">Back to employees</Link>
    </section>
  )
}
