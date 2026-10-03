# ACME Salary Management

A salary and employee management application with a Ruby on Rails JSON API and a React/Vite frontend.

## Requirements

- Ruby **3.4.5** (see `backend/.ruby-version`)
- Bundler and PostgreSQL
- Node.js **20.19 or newer** (see `frontend/.nvmrc`)
- npm

## Run locally

Run the backend and frontend in separate terminals. The frontend uses Vite's `/api` proxy to send requests to Rails, keeping the session cookie same-origin during local development.

### 1. Start PostgreSQL

Install and start PostgreSQL using your platform's package manager or an existing local installation. The backend's development configuration uses the local PostgreSQL socket and the database name `backend_development` by default. Ensure your local PostgreSQL role can create databases, or configure a `DATABASE_URL` in your shell before running the Rails commands.

### 2. Set up and start the backend

```sh
cd backend
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server -p 3000
```

The API health endpoint is available at `http://localhost:3000/up`; API endpoints are under `/api/v1`.

Seeding creates the exchange rates, one account per role, and up to 10,000 deterministic sample employees. It is safe to run again: existing users and their passwords are preserved, and employee rows are skipped unless `SEED_RESET=1` is set. Resetting employees deletes and recreates the employee dataset.

The seed has development-only password defaults in `backend/lib/demo_seed.rb`; do not reuse those credentials outside a local environment. For local secret overrides, provide `ADMIN_PASSWORD`, `HR_PASSWORD`, and `VIEWER_PASSWORD` in the shell before seeding. In production, all three variables are required. Configure production secrets in your hosting provider's secret/environment-variable settings, never in source control or this README. The seeded account email addresses are defined in the same seed file.

### 3. Set up and start the frontend

In a second terminal:

```sh
cd frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. By default, Vite proxies `/api` requests to `http://localhost:3000`. To use another backend URL, set `API_PROXY_TARGET` before starting Vite. The frontend's configured origin is `http://localhost:5173`; keep the Vite port unchanged unless you also update the backend's `FRONTEND_ORIGIN`.

## Tests and quality checks

### Backend

```sh
cd backend
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```

If the test database has not been initialized, run `RAILS_ENV=test bin/rails db:prepare` first.

### Frontend

```sh
cd frontend
npm test
npm run lint
npm run build
```

## Configuration notes

- Development and test databases are `backend_development` and `backend_test` by default. Use `DATABASE_URL` for a different PostgreSQL connection.
- The backend allows the frontend origin from `FRONTEND_ORIGIN`, defaulting to `http://localhost:5173` in development.
- Frontend API requests use `VITE_API_URL`, falling back to `/api/v1` in the API client.
- For the Render deployment blueprint, see `render.yaml`. Set production passwords and other secret values in the Render dashboard; do not commit them.
