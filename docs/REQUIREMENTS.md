# Requirements — ACME Salary Management

## Goal
Replace ACME's Excel-based salary tracking with a web app that lets the HR Manager maintain salary data for ~10,000 employees across multiple countries and answer "how does the org pay people?" in seconds.

## Persona
**HR Manager** — owns salary data, edits records daily, and fields pay questions from leadership (e.g. "What do engineers in India earn on average?"). Supported by an **Admin** who manages user access and **Viewers** (e.g. finance, leadership) who need read-only insight.

## Problem
Salary data lives in per-country spreadsheets in mixed currencies: slow to search and edit, no validation, no single source of truth.

## In Scope
1. **Sign in / sign out** — Rails 8 authentication with an httponly **session cookie**; every API call except login requires authentication.
2. **Roles (RBAC)** — enforced server-side on every action and reflected in the UI:

   | Role | Employees | Insights | Users & roles |
   |------|-----------|----------|---------------|
   | Admin | Full CRUD | View | Manage |
   | HR Manager | Full CRUD | View | — |
   | Viewer | Read-only | View | — |
3. **Employee management** — create, view, edit, delete. Fields: full name, email (unique), job title, department, country (ISO), currency (ISO 4217), salary, employment type, hire date. Validation errors shown inline.
4. **Employee list** — server-side pagination, sorting, search by name/email, filters by country, department, job title.
5. **Salary insights**
   - Per country: headcount, min / max / average / median salary (local currency **and** USD).
   - Per job title within a country: average salary.
   - Org-wide: headcount, headcount by country and department, USD salary distribution buckets.
6. **Currency normalization** — salaries stored in local currency; a static exchange-rate table converts to USD in SQL for cross-country figures. Every figure is labelled with its currency, and the UI shows the rates' "as of" date.
7. **Seed data** — 10,000 realistic employees across 9 countries generated with **Faker** (fixed random seed, so deterministic), loaded in seconds, plus one demo user per role.
8. **Developer experience** — `docker compose up` runs the full stack; CI runs tests, linting, and security scans.
9. **Hosting** — deployed to **Render** (final phase): public URL, managed PostgreSQL, seeded with the 10k dataset.

## Technical Constraints
- Backend: Ruby on Rails 8 (API mode), Ruby 3.3+, PostgreSQL.
- Frontend: React in **JavaScript** (Vite), Redux Toolkit + RTK Query for state.

## Delivery Process
Small, numbered, test-first steps. The AI agent **pauses after every step** with changed files, test results, and a suggested commit message; it **never commits**, so the developer reviews and makes every commit.

## Out of Scope (and why)
| Item | Reason |
|------|--------|
| Signup, password reset, SSO/OAuth | Admin creates accounts; extra auth surface doesn't serve the core problem. |
| Per-field or per-country permissions | Three roles cover the personas; finer rules can come later. |
| Payroll processing, tax, benefits | Separate domain with regional legal rules; this tool manages records, not payouts. |
| Live FX rates | External dependency; a static, dated table gives consistent, explainable figures. |
| Salary history / audit trail | Doubles data-model complexity; current records answer the stated questions. |
| Bulk Excel import/export | One-off migration, not a daily need. |
| Multi-tenant (multiple orgs) | Built for ACME only. |
| Org hierarchy / managers | Not needed for the persona's pay questions. |

## Assumptions
- Each employee has one current salary, in their country's currency.
- HR accepts a dated FX snapshot.
- 10k–100k rows need only good PostgreSQL indexes; no caching layer.

## Success Criteria
- List, search, and filter respond in < 200 ms on 10k employees; insights in < 300 ms.
- HR can answer the example questions above from the UI without exporting data.
- Each role can do exactly what the roles table allows; forbidden actions return 403.
- Seed completes in under 10 seconds.
- All test suites, RuboCop, Brakeman, and lint pass in CI.
- `docker compose up` yields a working app from a clean checkout.
- The hosted app on Render is reachable, seeded, and each demo role can log in.
