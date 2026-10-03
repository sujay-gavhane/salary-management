# ACME Salary Management — Agent Handoff

**Purpose:** Carry project context into another coding agent. This is a chronological, implementation-focused reconstruction of the conversation, not a verbatim transcript. The latest verified code and tests are authoritative; verify git status and rerun checks before continuing.

## Assignment and product requirements

Build a production-quality salary management application for ACME's HR team, which currently maintains 10,000 employees across countries in Excel. The HR Manager must maintain employee salary records and answer organization-pay questions.

- Rails 8 API, Ruby 3+, PostgreSQL.
- React frontend with Redux state management.
- A seed script for 10,000 employees.
- Fully functional and deployed software.
- Supporting artifacts: one-page requirements, planning/design notes, architecture diagrams, AI prompt instructions, and performance considerations.

The approved product model uses three roles:
- **Admin:** employee CRUD, insights, and user/role management.
- **HR Manager:** employee CRUD and insights.
- **Viewer:** read-only employees and insights.

Authentication is a Rails session cookie, not a bearer token. Frontend is React in JavaScript (not TypeScript). Seed data uses Faker, deterministic with a fixed random seed. Work proceeds in small, numbered, test-first steps: stop after every step, report tests and a suggested Conventional Commit; the agent never runs git add/commit/push. The developer commits manually.

### In-scope features

- Employee CRUD with name, unique email, job title, department, country, currency, salary, employment type, and hire date.
- Server-side search, filtering, sorting, and pagination.
- Salary insights: per-country min/max/average/median, job-title average within country, company headcount and breakdowns, salary distribution.
- Store salary in local currency. Convert to USD in SQL using a dated, static exchange-rate table; label currency and rate date.
- Cookie login/logout/current session, role authorization, and Admin user management.

Out of scope includes payroll/tax/benefits, live FX rates, multi-tenancy, salary history/audit trail, bulk Excel import/export, SSO/OAuth, password reset/signup, and fine-grained country/field permissions. Requirements are in [REQUIREMENTS.md](REQUIREMENTS.md).

## Architecture decisions

- The browser uses a single origin for the React app and `/api`. Vite proxies `/api` to Rails locally; on Render, a static-site rewrite proxies it to the API. This keeps the `SameSite=Lax` cookie first-party even though Render service hostnames are separate subdomains.
- Rails auth cookie: signed, `HttpOnly`, `SameSite=Lax`, `Secure` in production, 12-hour expiry. Session row expiry is checked server-side. State-changing requests require exact allowed `Origin`; POST/PATCH/PUT require JSON. CORS is locked to `FRONTEND_ORIGIN` with credentials.
- Pundit policy authorization applies on every controller action. Admin cannot delete/demote self. Changing a user's password ends their other sessions.
- Money stored as `decimal`; insights and cross-currency comparisons are calculated in PostgreSQL. Median uses `PERCENTILE_CONT`; distribution uses contiguous fixed USD 25,000 bands using `FLOOR` (not `width_bucket`) and includes empty bands.
- Employee list uses capped offset pagination, bound/escaped substring search, whitelisted sort keys, and USD conversion in SQL. No `pagy` dependency is used.
- React uses Redux Toolkit + RTK Query, React Router, PropTypes, Vitest, React Testing Library, MSW, and oxlint (the current Vite template's linter). Node is pinned to 20 in `frontend/.nvmrc`.
- Render hosting was added as the final deployment phase. Production requires `FRONTEND_ORIGIN`; production Docker does not boot during image build.

More detail and Mermaid diagrams: [DESIGN_NOTES.md](DESIGN_NOTES.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Chronological work completed

### Documentation phase
1. Created and user-approved [REQUIREMENTS.md](REQUIREMENTS.md), including roles, cookie auth, JavaScript, Faker, step-by-step pauses, and no agent commits.
2. Created [DESIGN_NOTES.md](DESIGN_NOTES.md) with schema/API/RBAC/hosting decisions and [ARCHITECTURE.md](ARCHITECTURE.md) with system, deployment, ER, request, login, and frontend diagrams.
3. Added Render deployment planning: managed PostgreSQL, Rails Docker web service, React static site, `/api/*` rewrite before SPA fallback, secrets supplied in the dashboard, seed and smoke test after deployment.

### Backend phase (completed; Rails 8.0.5.1)
4. Scaffolded API-only Rails/PostgreSQL app, RSpec, FactoryBot, Shoulda Matchers, Faker, Pundit, rack-cors, RuboCop, Brakeman. Installed no Solid stack. `backend/.gitignore` ignores Rails secrets. **Brakeman has one known EOL warning** because Rails 8.0.5.1 support ends 2026-11-07; the user explicitly chose to retain Rails 8.0 and leave the warning. Brakeman therefore exits 3 until policy/version changes.
5. Added `ExchangeRate`: ISO 4217 code primary key, `decimal(18,8)` positive rate, `as_of` date, model and database constraints/specs.
6. Added `Country` mapping for US/USD, GB/GBP, DE/EUR, NL/EUR, CA/CAD, IN/INR, SG/SGD, JP/JPY, AU/AUD. Added Employee schema/constraints/indexes, country-derived currency, validations, factories and specs. `pg_trgm` indexes support substring search.
7. Adapted Rails 8 generated auth to JSON session endpoints under `/api/v1/session`; removed password-reset artifacts. Added 12-hour signed cookie, session expiration/revocation, generic bad-credential response and 10-per-3-minute login limit. Pinned `json ~> 2.10` because json 3 breaks ActiveSupport 8.0's `quirks_mode` call.
8. Added roles, Pundit policies, `verify_authorized`, shared errors, Admin-only user management and password-change session invalidation.
9. Added employee CRUD and a list query with search, filters, sort whitelist, USD sorting and pagination. Money values serialize as 2-decimal strings.
10. Added SQL salary insights endpoints: `/api/v1/insights/summary`, `/countries`, and `/job_titles?country=...`; all roles can read them. USD conversion is performed inside SQL.
11. Added CORS and CSRF Origin/content-type validation.
12. Added deterministic Faker seed: eight exchange rates, three role demo users, 10,000 employees in 1,000-row `insert_all!` batches. `SEED_RESET=1` replaces employees; ordinary reruns skip employees and preserve existing users/passwords. Production seed requires `ADMIN_PASSWORD`, `HR_PASSWORD`, `VIEWER_PASSWORD`.

Backend verification at the seed step: **261 RSpec examples, 0 failures; RuboCop 81 files, 0 offenses**. Brakeman only reports the known Rails 8.0 end-of-support warning. Seed ran in 3.53 seconds, idempotent rerun in 0.06s, reset in 2.98s. All 10k employees validate. Warm HTTP timings with seeded data: list ~27ms, filtered/ordered list ~14ms, summary ~51ms, countries ~32ms, job titles ~19ms. These are local measurements, not hosted performance results.

Dev seeded demo accounts:
- `admin@acme.test` / `acme-admin-dev-2026`
- `hr@acme.test` / `acme-hr-dev-2026`
- `viewer@acme.test` / `acme-viewer-dev-2026`

### Frontend phase
13. Scaffolded `frontend/` with Vite 8.3 / React 19 JavaScript, Redux Toolkit 2.12, React Redux, React Router 7.18, PropTypes, Vitest 4.1, jsdom, Testing Library, oxlint and MSW 2.15. `frontend/.nvmrc` pins Node 20.20.2-compatible major; current shell may still use Node 16, so run `nvm use` from `frontend/`.
14. Added RTK Query API/session endpoints, Redux store, `credentials: 'include'`, Vite `/api` proxy, and 401 cache clearing for data endpoints. Session/login 401s are excluded to avoid reset loops. Verified login/session/employee requests through Vite's proxy with curl.
15. **In progress and not yet committed:** Login and routing. Implemented LoginPage, protected route/session check, role routes, app layout/nav, logout, forbidden/not-found pages, placeholder feature pages, shared loading/error states, login/routing tests and initial styles. The last verification completed successfully: `npm test` = 6 files / 31 tests passed; `npm run lint` = clean; `npm run build` = success (307ms). Files are currently uncommitted; see `git status`.

## Current state and next actions

1. The approved one-step workflow requires a pause/report after each step. Finish by reporting step 3.3 (login and routing) and wait for the developer's next approval before feature work; do not commit.
2. Next frontend step is the **Employees list table**: add RTK Query endpoint and tests; implement a paginated, sortable table with loading/empty/error states and test it. Following steps add search/filter controls, employee details/form, insights UI/charts, and Admin user management.
3. Verify every step under Node 20 with `npm test`, `npm run lint`, `npm run build`. Keep frontend API calls same-origin at `/api/v1`.
4. Complete frontend, deployment/config, artifact docs and final verification per approved requirements. Render deployment credentials, domains and live service provisioning require the user; never invent live URLs or secrets.

## Important caveats

- Do not silently change session cookie auth to bearer tokens, JavaScript to TypeScript, the three roles to a single user, or Redux Toolkit to TanStack Query.
- The workspace step plan and an attached personal prompt differed earlier. The **user-approved requirements and later explicit decisions above take precedence**.
- Don't cite a Brakeman-clean result; it warns on Rails version lifecycle and exits non-zero.
- Do not commit; the user makes commits after reviewing each step.
