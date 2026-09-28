# Architecture — ACME Salary Management

This doc shows how the system fits together, from the whole system down to single requests. The reasoning behind the design is in [DESIGN_NOTES.md](./DESIGN_NOTES.md).

## 1. System Context

```mermaid
flowchart LR
    hr(["HR Manager / Admin / Viewer"])
    subgraph client["Browser"]
        spa["React SPA<br/>Redux Toolkit + RTK Query"]
    end
    subgraph sameorigin["Same origin"]
        proxy["Static host + /api proxy<br/>(Vite dev server locally,<br/>Render static site in prod)"]
    end
    subgraph server["Backend"]
        api["Rails 8 API<br/>/api/v1"]
        db[("PostgreSQL<br/>employees, exchange_rates,<br/>users, sessions")]
    end

    hr --> spa
    spa -- "HTML / JS / CSS" --> proxy
    spa -- "JSON + session cookie<br/>/api/v1/*" --> proxy
    proxy -- "forwards /api/*" --> api
    api -- "SQL (ActiveRecord)" --> db
```

The browser only ever talks to **one origin**. That origin serves the React bundle and forwards every `/api/*` request to Rails. So the session cookie is always first-party, and `SameSite=Lax` works both locally and on Render.

Rails does all the business work:
- checks who you are (authentication)
- checks what your role allows (authorization)
- validates input
- computes the salary insights in SQL

## 2. Deployment View (Render)

```mermaid
flowchart TB
    user(["Browser"])
    subgraph render["Render (render.yaml Blueprint)"]
        web["salary-web<br/>Static site (frontend/dist)"]
        api["salary-api<br/>Docker web service<br/>preDeploy: db:migrate<br/>health: GET /up"]
        db[("salary-db<br/>Managed PostgreSQL 16")]
    end

    user -- "HTTPS" --> web
    web -- "rewrite 1: /api/* → salary-api/api/*" --> api
    web -. "rewrite 2: /* → /index.html" .-> web
    api -- "DATABASE_URL" --> db
```

**Rewrite order matters.** The `/api/*` rule must come before the catch-all SPA fallback. Otherwise API calls would get back `index.html`.

`onrender.com` is a public suffix, so `salary-web` and `salary-api` count as different sites. The rewrite makes them appear as one origin to the browser.

Local development mirrors this layout:
- **Vite dev server:** proxies `/api` to `localhost:3000`.
- **Docker Compose:** runs `db`, `backend`, and `frontend`.

## 3. Backend Request Pipeline

```mermaid
flowchart LR
    req["HTTP request"] --> rack["Rack middleware<br/>CORS, Cookies"]
    rack --> ctrl["Api::V1 controller"]

    subgraph concerns["Controller concerns"]
        auth["Authentication<br/>cookie → Session → Current.user"]
        origin["OriginCheck<br/>writes must match FRONTEND_ORIGIN"]
        errors["ErrorHandling<br/>exceptions → errors JSON"]
    end

    ctrl --> auth --> origin
    ctrl --> pol["Pundit policy<br/>authorize + verify_authorized"]
    pol --> query["Query object<br/>EmployeeSearch / SalaryInsights"]
    query --> model["ActiveRecord models"]
    model --> pg[("PostgreSQL")]
    query --> ser["Serializer (PORO)"]
    ser --> res["JSON response"]
    ctrl -. "on failure" .-> errors
```

Controllers stay thin. Each one:
1. Authenticates the user.
2. Authorizes the action.
3. Hands the whitelisted params to a query object or model.
4. Serializes the result.

Every failure goes through one `ErrorHandling` concern, so all errors share a single JSON shape:

| Failure | Status |
|---------|--------|
| Validation error | 422 |
| Record not found | 404 |
| Pundit forbidden | 403 |
| Unauthenticated | 401 |
| Bad parameter | 400 |
| Rate limited | 429 |
| Write from a foreign or missing `Origin` | 403 (`invalid_origin`) |
| Write body that isn't JSON | 415 |

## 4. Data Model (ER Diagram)

```mermaid
erDiagram
    USERS ||--o{ SESSIONS : "owns"
    EXCHANGE_RATES ||--o{ EMPLOYEES : "converts salary of"

    USERS {
        bigint id PK
        string email_address UK "normalized lowercase"
        string password_digest "bcrypt"
        string name
        string role "admin, hr_manager, viewer"
        datetime created_at
        datetime updated_at
    }

    SESSIONS {
        bigint id PK
        bigint user_id FK
        string ip_address
        string user_agent
        datetime created_at "expires after 12h"
        datetime updated_at
    }

    EXCHANGE_RATES {
        string currency PK "ISO 4217, 3 uppercase letters"
        decimal rate_to_usd "18,8 and > 0"
        date as_of
    }

    EMPLOYEES {
        bigint id PK
        string full_name
        string email UK "normalized lowercase"
        string job_title
        string department
        string country "ISO 3166-1 alpha-2"
        string currency FK "derived from country"
        decimal salary "12,2 and > 0, annual gross"
        string employment_type "full_time, part_time, contract"
        date hire_date
        datetime created_at
        datetime updated_at
    }
```

`employees` has no link to `users`. Users are the people who operate the system; employees are the records being managed.

`employees.currency` is a foreign key to `exchange_rates`. So every salary can be converted to USD with a plain `JOIN`, and a salary can never be stored in a currency that has no rate.

Every column is `NOT NULL` unless stated otherwise. Enums and `salary > 0` are enforced with `CHECK` constraints that mirror the model validations.

## 5. Login & Session Cookie

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant B as React SPA
    participant P as Same-origin proxy
    participant A as Rails API
    participant D as PostgreSQL

    U->>B: Submit email + password
    B->>P: POST /api/v1/session (JSON, credentials include)
    P->>A: Forward request
    A->>A: rate_limit (10 per 3 min per IP)
    A->>A: OriginCheck (Origin == FRONTEND_ORIGIN)
    A->>D: Find user by email_address
    A->>A: authenticate (bcrypt)
    alt valid credentials
        A->>D: INSERT INTO sessions
        A-->>P: 201 user + Set-Cookie session_id (signed, HttpOnly, Secure, SameSite=Lax, 12h)
        P-->>B: 201 + first-party cookie
        B->>B: RTK Query caches Session, redirect to /employees
    else invalid credentials
        A-->>B: 401 generic "Invalid email or password"
    end

    Note over B,A: Later requests send the cookie automatically

    B->>P: GET /api/v1/session
    P->>A: Forward with cookie
    A->>D: Find session by signed id (not expired)
    A-->>B: 200 current user and role
```

JavaScript never sees the session ID: the cookie is `HttpOnly`, so an XSS bug can't steal it.

Logging out (`DELETE /session`) deletes the session row, so the cookie stops working immediately, even before it expires.

## 6. Employee List Request

```mermaid
sequenceDiagram
    autonumber
    participant UI as EmployeesPage
    participant S as Redux store
    participant Q as RTK Query api
    participant A as EmployeesController
    participant ES as EmployeeSearch
    participant D as PostgreSQL

    UI->>S: dispatch setFilters (q, country, sort, page)
    S-->>UI: new filter state (also synced to URL)
    UI->>Q: useListEmployeesQuery(filters) after 300 ms debounce
    alt cached for these args
        Q-->>UI: cached data (no request)
    else not cached
        Q->>A: GET /api/v1/employees?q=asha&country=IN&sort=salary_usd&direction=desc&page=1
        A->>A: authenticate, then authorize Employee index
        A->>ES: call(whitelisted params)
        ES->>ES: validate sort key, clamp per_page to 100
        ES->>D: SELECT employees JOIN exchange_rates WHERE ILIKE (bound) ORDER BY LIMIT OFFSET
        ES->>D: SELECT COUNT(*) with the same filters
        D-->>ES: rows + total
        ES-->>A: relation + meta
        A-->>Q: 200 data + meta
        Q-->>UI: rows, loading false
    end
```

The search string is sent only as a bound parameter. Sort keys are looked up in a fixed map of SQL expressions, and any key outside it returns `400`.

The query uses the trigram GIN indexes for `ILIKE` and the `(country, job_title)` index for filters. It returns one page plus a count, so rows are never loaded just to count them.

## 7. Insights Request

```mermaid
sequenceDiagram
    autonumber
    participant UI as InsightsPage
    participant Q as RTK Query api
    participant A as InsightsController
    participant SI as SalaryInsights
    participant D as PostgreSQL

    UI->>Q: useGetCountryInsightsQuery()
    Q->>A: GET /api/v1/insights/countries
    A->>A: authenticate, then authorize insights
    A->>SI: by_country
    SI->>D: One GROUP BY query with MIN, MAX, AVG, PERCENTILE_CONT(0.5) JOIN exchange_rates
    D-->>SI: one row per country
    SI->>D: SELECT MAX(as_of) FROM exchange_rates
    SI-->>A: stats (local + USD) + rates_as_of
    A-->>Q: 200 data + rates_as_of
    Q-->>UI: render stat table and Recharts charts

    Note over UI,Q: Creating, editing, or deleting an employee invalidates the Employee and Insights tags, so this refetches
```

Each insight is **a single SQL statement**. Nothing is aggregated in Ruby. For example:

```sql
SELECT e.country, e.currency, COUNT(*) AS headcount,
       MIN(e.salary) AS min, MAX(e.salary) AS max, AVG(e.salary) AS avg,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.salary) AS median,
       r.rate_to_usd
FROM employees e
JOIN exchange_rates r ON r.currency = e.currency
GROUP BY e.country, e.currency, r.rate_to_usd
ORDER BY e.country;
```

Each country has exactly one currency, so each USD stat is just the local stat × `rate_to_usd`.

Figures that span countries, like department averages and distribution buckets, work differently: they compute `salary * rate_to_usd` per row inside the aggregate. Buckets are fixed 25,000 USD bands, computed as `FLOOR(salary_usd / 25000)` and grouped in SQL. Empty bands in between are filled with zero, so the histogram has no gaps.

## 8. Frontend Component Tree

```mermaid
flowchart TD
    main["main.jsx<br/>Redux Provider + RouterProvider"] --> app["App routes"]
    app --> login["LoginPage"]
    app --> guard["RequireAuth<br/>(GET /session)"]

    guard --> layout["AppLayout<br/>NavBar (role-aware), UserMenu, Outlet"]

    layout --> emp["EmployeesPage"]
    emp --> toolbar["EmployeesToolbar<br/>SearchInput (debounced), FilterSelects"]
    emp --> table["EmployeesTable<br/>SortableHeader, RowActions (useCan)"]
    emp --> pager["Pagination"]

    layout --> detail["EmployeeDetailPage"]
    detail --> money["Money (amount + currency)"]
    detail --> del["DeleteEmployeeDialog"]

    layout --> form["EmployeeFormPage<br/>(new / edit, RequireRole admin, hr)"]
    form --> ef["EmployeeForm<br/>country → currency auto-fill,<br/>API errors mapped to fields"]

    layout --> ins["InsightsPage"]
    ins --> cards["SummaryCards"]
    ins --> ctab["CountryStatsTable (local + USD)"]
    ins --> jt["JobTitleInsights<br/>CountrySelect + table"]
    ins --> dept["DepartmentChart (Recharts)"]
    ins --> dist["SalaryDistributionChart (Recharts)"]
    ins --> asof["RatesAsOfBadge"]

    layout --> users["UsersPage<br/>(RequireRole admin)"]
    users --> utab["UsersTable"]
    users --> uform["UserFormDialog"]

    app --> nf["NotFoundPage"]
```

Shared building blocks:
- `Money`, `LoadingState`, `EmptyState`, `ErrorState`, `ConfirmDialog`, and `FormField` live in `src/components/`.
- The `useCan(action)` hook reads the current user's role. It hides controls the role can't use; the API still enforces the rules.

## 9. Frontend State

```mermaid
flowchart LR
    subgraph store["Redux store"]
        api["api (RTK Query)<br/>tags: Session, Employee,<br/>Insights, User"]
        filters["employeeFilters slice<br/>q, country, department,<br/>job_title, sort, page"]
    end

    url["URL query params"] <--> filters
    filters --> api
    api -- "fetchBaseQuery<br/>credentials include" --> backend["/api/v1"]
    api -- "401" --> reauth["baseQuery wrapper<br/>reset api state, go to /login"]
    mutations["create / update / delete"] -- "invalidate Employee + Insights" --> api
```

Server data lives only in the RTK Query cache; it's never copied into hand-written slices.

The only client state is the list filters. They're synced to the URL, so a filtered view can be bookmarked or shared.
