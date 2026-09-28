# Design Notes — ACME Salary Management

Planning notes behind the [requirements](./REQUIREMENTS.md). Diagrams live in [ARCHITECTURE.md](./ARCHITECTURE.md).

## 1. Toolchain

| Tool | Version | Notes |
|------|---------|-------|
| Ruby | 3.4.5 | pinned in `backend/.ruby-version` |
| Rails | 8.0.x | API mode |
| PostgreSQL | 16 in Docker (14+ locally) | needs the `pg_trgm` extension |
| Node | 20 LTS | pinned in `frontend/.nvmrc`; Vite requires Node 18+ |

## 2. Domain Model

### `employees`
| Column | Type | Constraints |
|--------|------|-------------|
| `full_name` | string(120) | NOT NULL, length 2–120; whitespace collapsed |
| `email` | string(254) | NOT NULL, unique, valid format; normalized to lowercase |
| `job_title` | string(100) | NOT NULL |
| `department` | string | NOT NULL, one of the allowed departments (model) |
| `country` | string(2) | NOT NULL, CHECK `~ '^[A-Z]{2}$'`, one of the supported countries (model) |
| `currency` | string(3) | NOT NULL, FK → `exchange_rates.currency`; **derived from `country`**, direct assignment ignored |
| `salary` | decimal(12,2) | NOT NULL, CHECK `salary > 0`, model caps it below 10^10 (annual gross, local currency) |
| `employment_type` | string | NOT NULL, CHECK in (`full_time`, `part_time`, `contract`); Rails enum |
| `hire_date` | date | NOT NULL; model validates it's not in the future (a CHECK can't use `CURRENT_DATE`) |

Indexes:
- unique on `email`
- `(country, job_title)`, used for country filters and job-title-in-country stats
- `department`, `job_title`, `hire_date`, used for filters and sorting. Sorting by `salary_usd` is computed through the rate join, so a `salary` index wouldn't help it.
- GIN `gin_trgm_ops` on `full_name` and `email`, for `ILIKE '%q%'` search

### `exchange_rates`
| Column | Type | Constraints |
|--------|------|-------------|
| `currency` | string(3) | PK, ISO 4217, CHECK `~ '^[A-Z]{3}$'`; normalized to uppercase |
| `rate_to_usd` | decimal(18,8) | NOT NULL, CHECK `> 0`; 1 unit of local currency = `rate_to_usd` USD |
| `as_of` | date | NOT NULL |

### `users` and `sessions`
These tables come from the Rails 8 authentication generator.
- `users`: `email_address` (unique, normalized), `password_digest`, `name`, `role`.
  - `role` is a string enum: `admin`, `hr_manager`, `viewer`. It's NOT NULL, defaults to `viewer`, and has a CHECK constraint.
- `sessions`: `user_id`, `ip_address`, `user_agent`, and timestamps.
  - Sessions have an absolute lifetime of 12 hours. Expired sessions are rejected and destroyed.

### Supported countries
Each country maps to exactly one currency. This mapping is the single source of truth, kept in `Country::CURRENCIES`.

| Country | Currency | | Country | Currency |
|---------|----------|-|---------|----------|
| US | USD | | IN | INR |
| GB | GBP | | SG | SGD |
| DE | EUR | | JP | JPY |
| NL | EUR | | AU | AUD |
| CA | CAD | | | |

## 3. Roles & Permissions

Permissions are enforced with Pundit policies. Every controller action calls `authorize`, and `after_action :verify_authorized` guarantees that no action skips it.

| Action | Admin | HR Manager | Viewer |
|--------|:-----:|:----------:|:------:|
| List / view employees | ✓ | ✓ | ✓ |
| Create / edit / delete employees | ✓ | ✓ | ✗ |
| View insights | ✓ | ✓ | ✓ |
| Manage users & roles | ✓ | ✗ | ✗ |

Guardrails:
- An admin can't delete their own account or change their own role, so the system can't be left with no admins.
- Changing a user's password ends all of that user's other sessions. If an admin changes their own password, the session making the change is kept.
- Non-admins get 403 on every `/users` request, before any lookup, so they can't probe which user ids exist.
- The UI hides actions a role can't perform, but the API is the source of truth.

## 4. Authentication & Session Security

- `POST /api/v1/session` checks the credentials and creates a `Session` row. It sets a signed session cookie:
  - `httponly`
  - `secure` in production
  - `SameSite=Lax`
  - expires after 12 hours
- API mode needs cookie support added back: `ActionDispatch::Cookies` and `ActionController::Cookies`.
- **Same-site deployment**: the React app calls `/api/...` on its own origin.
  - In local dev and Docker Compose, a Vite dev-server proxy forwards those calls to Rails.
  - On Render, a static-site rewrite rule forwards them to the API service (see [Hosting](#8-hosting-render)).
  - So the cookie is first-party, and CORS only matters when the API is hit directly.
- **CORS**: allows only the `FRONTEND_ORIGIN` value, with `credentials: true`.
- **CSRF protection** has three layers:
  - `SameSite=Lax` blocks cross-site cookie sends on POST, PATCH, and DELETE.
  - Every state-changing request must have a JSON `Content-Type`.
  - The `Origin` header must match `FRONTEND_ORIGIN`.
- **Login rate limit**: 10 attempts per 3 minutes per IP, using Rails 8 `rate_limit`. Exceeding it returns 429.
- Failed logins return the same generic message whether the email or the password was wrong, so accounts can't be discovered.

## 5. API Contract (`/api/v1`, JSON)

### Conventions
- **Success**: a resource returns `{ "data": ... }`. A collection returns `{ "data": [...], "meta": { ... } }`.
- **Errors**: `{ "errors": [{ "code": "validation_failed", "field": "email", "message": "has already been taken" }] }`.
- **Status codes**:
  - `400`: bad parameter
  - `401`: unauthenticated
  - `403`: forbidden
  - `404`: not found
  - `422`: validation failed
  - `429`: rate limited
  - `403` with code `invalid_origin`: a write whose `Origin` isn't `FRONTEND_ORIGIN`
  - `415`: a POST, PATCH, or PUT that isn't `application/json`
- Money is serialized as a string (e.g. `"85000.00"`) so it keeps its decimal precision, and always comes with its currency.

### Endpoints

| Method & path | Roles | Purpose |
|---------------|-------|---------|
| `POST /session` | public | Log in `{ email_address, password }` → `201 { data: user }` |
| `GET /session` | any | Current user → `200` or `401` |
| `DELETE /session` | any | Log out → `204` |
| `GET /employees` | any | List (see params below) |
| `GET /employees/:id` | any | Show |
| `POST /employees` | admin, hr | Create `{ employee: {...} }` → `201` |
| `PATCH /employees/:id` | admin, hr | Update → `200` |
| `DELETE /employees/:id` | admin, hr | Delete → `204` |
| `GET /lookups` | any | Countries (with currency), departments, job titles, employment types — feeds filters and forms |
| `GET /insights/summary` | any | Org headcount, headcount and average USD salary by country and by department, USD salary distribution buckets |
| `GET /insights/countries` | any | Per country: headcount, min / max / avg / median in local currency **and** USD |
| `GET /insights/job_titles?country=IN` | any | Per job title in a country: headcount and average salary (local and USD) |
| `GET /users` | admin | List users |
| `POST /users` | admin | Create user with role |
| `PATCH /users/:id` | admin | Update name, role, or password |
| `DELETE /users/:id` | admin | Delete user (not self) |

Every insights response includes `rates_as_of` (the most recent `exchange_rates.as_of`).

### `GET /employees` parameters
| Param | Rules |
|-------|-------|
| `page` | integer ≥ 1, default 1 |
| `per_page` | default 25, **max 100** |
| `q` | case-insensitive substring match on name or email |
| `country`, `department`, `job_title` | exact match; unknown values give an empty result, not an error |
| `sort` | whitelist: `full_name`, `email`, `job_title`, `department`, `country`, `hire_date`, `salary_usd`; default `full_name` |
| `direction` | `asc` or `desc` |

`salary_usd` sorts across currencies by joining `exchange_rates`; sorting by local salary would mix units. Any sort key outside the whitelist returns `400`.

### Sample responses

```json
// GET /api/v1/employees?country=IN&per_page=1
{
  "data": [{
    "id": 42, "full_name": "Asha Rao", "email": "asha.rao@acme.test",
    "job_title": "Software Engineer", "department": "Engineering",
    "country": "IN", "currency": "INR", "salary": "2400000.00",
    "salary_usd": "28800.00", "employment_type": "full_time",
    "hire_date": "2021-04-12"
  }],
  "meta": { "page": 1, "per_page": 1, "total_count": 1120, "total_pages": 1120 }
}
```

```json
// GET /api/v1/insights/countries
{
  "data": [{
    "country": "IN", "currency": "INR", "headcount": 1120,
    "local": { "min": "600000.00", "max": "9800000.00", "avg": "2310000.00", "median": "2050000.00" },
    "usd":   { "min": "7200.00",   "max": "117600.00",  "avg": "27720.00",   "median": "24600.00" }
  }],
  "rates_as_of": "2026-09-01"
}
```

## 6. Backend Structure

```
app/
  controllers/api/v1/   sessions, employees, lookups, insights, users (thin)
  controllers/concerns/ authentication, error_handling, origin_check
  models/               employee, exchange_rate, user, session, current, country
  policies/             application, employee, insights, user
  queries/              EmployeeSearch (filter/sort/paginate), SalaryInsights (SQL aggregates)
  serializers/          plain Ruby objects (EmployeeSerializer, UserSerializer)
```

- **`EmployeeSearch`**: takes params that are already whitelisted and returns a relation plus pagination metadata. Search uses `ILIKE` with bound parameters, and sort keys map to SQL expressions through a hash. Raw param values never reach SQL.
- **`SalaryInsights`**: one SQL query per insight.
  - Uses `GROUP BY` with `MIN`, `MAX`, `AVG`, and `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ...)`.
  - USD figures come from joining `exchange_rates` in SQL, never by converting in Ruby.
  - Distribution buckets are fixed 25,000 USD bands: `FLOOR(salary_usd / 25000)`, grouped in SQL. Empty bands up to the highest salary are filled with zero. Fixed round-number edges ("$50k–$75k") read better than `width_bucket`'s data-dependent edges.
  - `PERCENTILE_CONT` computes in double precision. The median is cast back to `numeric` and rounded to 2 decimals; at salaries below 10^10 that rounding is exact. All other stats stay `numeric` throughout.
- **Serializers** are hand-written POROs. There are only a few resources, and it avoids adding a gem.
- **Pagination** uses offset/limit with a capped `per_page`, returning the count in the metadata.

## 7. Frontend Structure

JavaScript + Vite, React Router, Redux Toolkit + RTK Query, Recharts, Vitest + React Testing Library + MSW.

### Page map
| Route | Page | Access |
|-------|------|--------|
| `/login` | Login | public |
| `/employees` | Employees list (table, search, filters, sort, pagination) | any role |
| `/employees/new` | Employee form | admin, hr |
| `/employees/:id` | Employee detail | any role |
| `/employees/:id/edit` | Employee form | admin, hr |
| `/insights` | Insights dashboard (country table, job-title-in-country table, department and distribution charts) | any role |
| `/users` | User management | admin |
| `*` | Not found | — |

### State
- **RTK Query `api` slice**: owns all server state.
  - Endpoints for session, employees, lookups, insights, and users.
  - Uses `credentials: 'include'`.
  - Cache tags `Employee`, `Insights`, `User`, and `Session` handle invalidation. Creating, editing, or deleting an employee invalidates both `Employee` and `Insights`.
- **`employeeFilters` slice**: `q`, filters, sort, and page, so the list keeps its state when you move between pages. It's synced to URL query params, so links can be shared.
- **Current user**: comes from `GET /session`. A route guard and a `useCan(action)` hook read the role.
- **Global 401 handling**: a `baseQuery` wrapper resets the API state and redirects to `/login`.

### UX rules
- Search is debounced by 300 ms.
- Every page handles loading, empty, and error states.
- API validation errors map onto form fields.
- Forms use labelled inputs and full keyboard navigation.
- Choosing a country auto-fills its currency, which is read-only.

## 8. Hosting (Render)

Hosting is the last phase, after local verification. Everything is defined in a `render.yaml` Blueprint at the repo root.

| Render resource | Type | Details |
|-----------------|------|---------|
| `salary-db` | PostgreSQL | Managed Postgres 16 |
| `salary-api` | Web service (Docker) | Built from `backend/Dockerfile`. `preDeployCommand: bin/rails db:migrate`; health check at `GET /up` |
| `salary-web` | Static site | `npm ci && npm run build` in `frontend/`, publishing `dist/` |

### Why the frontend proxies `/api`

`onrender.com` is on the Public Suffix List, so `salary-web.onrender.com` and `salary-api.onrender.com` count as **different sites**. The browser wouldn't send a `SameSite=Lax` cookie between them.

The fix is two static-site rewrite rules, in this order:
1. `/api/*` → `https://salary-api.onrender.com/api/*` (proxied, so the browser only ever sees the frontend origin)
2. `/*` → `/index.html` (fallback for SPA routing)

The session cookie is therefore set and sent first-party, with no change to the auth design.

### Environment variables

| Service | Variables |
|---------|-----------|
| `salary-api` | `DATABASE_URL` (from `salary-db`), `RAILS_MASTER_KEY` (set manually, never committed), `FRONTEND_ORIGIN=https://salary-web.onrender.com`, `RAILS_ENV=production`, `ADMIN_PASSWORD` / `HR_PASSWORD` / `VIEWER_PASSWORD` (set manually) |
| `salary-web` | `VITE_API_URL=/api/v1` (relative, via the rewrite) |

### Rails production config

- The app is generated with `--skip-solid`. Solid Queue and Cable aren't needed, and it avoids extra databases.
- The cache store is `:memory_store`, which is enough for the login rate limiter on a single instance. Moving to Solid Cache or Redis is the step before scaling out.
- `config.assume_ssl = true` and `config.force_ssl = true`, because Render terminates TLS.

### Seeding and smoke test

- Seed once from the Render shell with `bin/rails db:seed`. Seeds are idempotent, so running it again is safe.
- Smoke test from the command line:
  - `curl` `/up`
  - log in as each role
  - fetch the employee list and the insights endpoints

### Free-tier caveats

- Web services spin down when idle, so the first request after idle has a cold start.
- Free Postgres instances expire after a limited period.

Both are documented in the README. Neither affects correctness.

## 9. Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Auth transport | Session cookie (Rails 8 generator) | Built into Rails, httponly (unreadable by JS, so XSS can't steal it), revocable per session row |
| Authorization | Pundit | Small, explicit, one policy class per resource, easy to spec |
| Currency | Derived from country; stored for SQL joins | Enforces the one-currency-per-country assumption and removes a class of data errors |
| USD conversion | SQL join on a static `exchange_rates` table | Consistent, explainable figures; no external dependency |
| Money type | `decimal(12,2)` | Exact arithmetic; floats would drift |
| Search | `ILIKE` + trigram indexes | Simple, and scales to 1M rows without a search engine |
| Pagination | Offset with a capped `per_page` | Fine at 10k–100k rows; keyset pagination noted as the path to 1M+ |
| State management | Redux Toolkit + RTK Query | Meets the Redux constraint, with built-in caching and invalidation |
| Charts | Recharts | Declarative React API, enough for bars and histograms |
| Seed | Faker with a fixed seed, `insert_all` in batches of 1,000 | Deterministic and runs in seconds |
| Hosting | Render Blueprint (`render.yaml`) with a static-site `/api` rewrite | Infrastructure as code; keeps the session cookie first-party on `onrender.com` |

Fuller trade-off analysis will go in `TRADEOFFS.md` during wrap-up.

## 10. Assumptions
- Salaries are **annual gross** amounts.
- Departments come from a fixed list: Engineering, Product, Design, Sales, Marketing, Finance, HR, Operations, Support, Legal. Job titles are free text, seeded from a realistic set per department.
- Employee email is the natural unique key; there's no separate employee number.
- Exchange rates are a snapshot seeded by migration or seed; there's no UI to edit them in v1.

## 11. Open Questions
1. **Demo passwords**: dev defaults are documented in the README and overridable with `ADMIN_PASSWORD`, `HR_PASSWORD`, and `VIEWER_PASSWORD`. On Render these must be set manually. Are you happy with that approach?

Resolved:
- Node upgraded to 20 LTS (`nvm install 20`); it will be pinned in `frontend/.nvmrc`.
- Hosted deployment on Render added as the final phase (see [Hosting](#8-hosting-render)).
