import { Link } from 'react-router'

export default function NotFoundPage() {
  return (
    <section>
      <h1>Page not found</h1>
      <Link to="/employees">Back to employees</Link>
    </section>
  )
}
