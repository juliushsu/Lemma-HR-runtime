# HR+ MVP v1 API Smoke Checklist

Scope:
- `/api/me`
- `/api/hr/employees`

Assumptions:
- foundation + HR migrations have run.
- minimal seed has run (`supabase/seeds/base/hr_mvp_v1_minimal_seed.sql`).
- test user has valid bearer token.

## A) `/api/me` smoke

### Request

```bash
curl -sS \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  http://localhost:3000/api/me
```

### Expected success
- HTTP `200`
- `schema_version = "auth.me.v1"`
- `data.user` not null
- `data.memberships` length >= 1
- `data.current_org` not null
- `data.current_company` may be null or object
- `data.locale` exists
- `data.environment_type` exists

### Failure cases
1. Missing token
- expected HTTP `401`
- body contains unauthorized error

2. Invalid/expired token
- expected HTTP `401`
- body contains unauthorized error

3. User has no membership
- expected result: either HTTP `200` with empty memberships and null current context, or HTTP `401/403` by policy decision
- current implementation should be checked to ensure product expectation is explicit

## B) `/api/hr/employees` smoke

### Request (minimal)

```bash
curl -sS \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  "http://localhost:3000/api/hr/employees?org_id=10000000-0000-0000-0000-000000000001&company_id=20000000-0000-0000-0000-000000000001&page=1&page_size=20"
```

### Expected success
- HTTP `200`
- `schema_version = "hr.employee.list.v1"`
- `meta.request_id` exists
- `meta.timestamp` exists
- `error = null`
- `data.items` array
- seeded data returns at least 3 employees
- each item contains:
  - `employee_code`
  - `display_name`
  - `employment_status`
  - `department` (object or null)
  - `position` (object or null)
  - `manager` (object or null)

### Optional filter checks
1. `employment_status=active`
- expected list contains only active employees

2. `department_id=<HR_DEPARTMENT_ID>`
- expected only employees in that department

3. `keyword=Mike`
- expected includes `EMP-0003` seeded employee

### Failure cases
1. Missing token
- expected HTTP `401`
- error code: `UNAUTHORIZED`

2. Missing `org_id`/`company_id` when session cannot derive scope
- expected HTTP `403`
- error code: `SCOPE_FORBIDDEN`

3. Scope mismatch (user not in org/company/environment)
- expected HTTP `403`
- error code: `SCOPE_FORBIDDEN`

4. RLS blocking due to wrong environment_type/demo separation
- expected empty data or forbidden depending on membership/scope
