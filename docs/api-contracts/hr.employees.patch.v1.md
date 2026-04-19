# `PATCH /api/hr/employees/:id` Contract

## 1. Endpoint Metadata

- method: `PATCH`
- path: `/api/hr/employees/:id`
- schema_version: `hr.employee.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required
- scope: resolved from selected context and optional `org_id` / `company_id` / `branch_id` / `environment_type` query params; caller must have writable membership in the resolved scope
- environment support:
  - deployment: current app route can run in staging or production deployment environments
  - data scope: runtime supports any writable membership-bound employee scope; commonly `production`, `demo`, `sandbox`
  - write is blocked when preview override is read-only
- canonical truth-source:
  - primary write target: `public.employees`
  - manager relation validation also reads `public.employees`
  - department and position display names are derived elsewhere and are not written by this endpoint

## 2. Request Contract

### Path params

| Name | Type | Required | UUID support | `employee_code` support | Runtime rule |
| --- | --- | --- | --- | --- | --- |
| `id` | `string` | yes | yes | no | current PATCH route writes by `employees.id` only |

Notes:

- Unlike `GET /api/hr/employees/:id`, this PATCH route does not support `employee_code` path lookup.
- If a non-UUID code-like value is sent in the path, runtime will attempt `eq("id", value)` and typically return `404 EMPLOYEE_NOT_FOUND`.

### Query params

| Name | Type | Required | Purpose |
| --- | --- | --- | --- |
| `org_id` | `uuid` | no | scope override / disambiguation |
| `company_id` | `uuid` | no | scope override / disambiguation |
| `branch_id` | `uuid \| null` | no | branch scope narrowing |
| `environment_type` | `string` | no | scope override / disambiguation |

### Body

Only allowlisted keys are considered. All non-allowlisted keys are ignored.

| Field | Type | Required | Nullable | Writable | Runtime notes |
| --- | --- | --- | --- | --- | --- |
| `preferred_name` | `string` | no | yes | yes | written directly to `employees.preferred_name` |
| `display_name` | `string` | no | yes | yes | written directly |
| `work_email` | `string` | no | yes | yes | written directly |
| `personal_email` | `string` | no | yes | yes | written directly |
| `mobile_phone` | `string` | no | yes | yes | written directly |
| `nationality_code` | `string` | no | yes | yes | written directly |
| `work_country_code` | `string` | no | yes | yes | written directly |
| `preferred_locale` | `string` | no | yes | yes | written directly |
| `timezone` | `string` | no | yes | yes | written directly |
| `department_id` | `uuid` | no | yes | yes | written directly; route does not prevalidate existence |
| `position_id` | `uuid` | no | yes | yes | written directly; route does not prevalidate existence |
| `manager_employee_id` | `uuid \| null` | no | yes | yes | explicit `null` clears manager; non-null is validated for existence, self-reference, and cycle |
| `employment_type` | `string` | no | no | yes | written directly; route does not prevalidate enum here |
| `employment_status` | `active \| inactive \| on_leave \| terminated` | no | no | yes | route validates allowed status values |
| `hire_date` | `date string` | no | yes | yes | written directly |
| `termination_date` | `date string` | no | yes | yes | written directly |
| `gender_note` | `string` | no | yes | yes | written directly |
| `notes` | `string` | no | yes | yes | written directly |
| `branch_id` | `uuid \| null` | no | yes | yes | written directly |

### Unsupported fields

Common unsupported keys that are ignored if sent:

- `employee_code`
- `legal_name`
- `full_name_local`
- `full_name_latin`
- `department_name`
- `position_title`
- `manager_name`
- `gender`
- `birth_date`
- `emergency_contact_name`
- `emergency_contact_phone`
- nested objects such as `employee`, `department`, `position`, `manager`, `current_assignment`

If the body only contains unsupported keys, runtime returns `400 INVALID_REQUEST` with message `No updatable fields provided`.

## 3. Response Contract

- structure: flat write acknowledgement
- envelope: canonical `{ schema_version, data, meta, error }`

### Success example

```json
{
  "schema_version": "hr.employee.update.v1",
  "data": {
    "employee_id": "71000000-0000-0000-0000-000000000104"
  },
  "meta": {
    "request_id": "33333333-3333-3333-3333-333333333333",
    "timestamp": "2026-04-18T00:00:00.000Z"
  },
  "error": null
}
```

### Guaranteed fields on `200`

- `schema_version`
- `data.employee_id`
- `meta.request_id`
- `meta.timestamp`
- `error = null`

### Optional fields

- none in the current success payload

### Missing fields in current runtime

The current PATCH response does not return:

- updated employee detail fields
- `department_name`
- `position_title`
- `manager_name`
- nested `employee`, `department`, `position`, `manager`, or `current_assignment`
- `updated_at`

### Derived fields

This route does not return derived display fields.

## 4. UI Consumption Rules

### Cross-Route Integration Rule

- `GET /api/hr/employees/:id` supports both employee UUID and exact `employee_code`
- `PATCH /api/hr/employees/:id` supports employee UUID only and does not support `employee_code`
- if the UI enters the employee detail page from GET, it must retain `data.employee.id` before attempting PATCH
- PATCH success response cannot be used as the employee detail view model
- after successful PATCH, the UI must refetch canonical `GET /api/hr/employees/:id` detail before rendering view mode
- Readdy must not reuse a GET path value blindly for PATCH unless it has confirmed that value is the employee UUID
### Direct display fields

- `data.employee_id` may be used for confirmation or logging only

### Fields that need mapping or refetch

- all display fields used by employee detail UI must come from `GET /api/hr/employees/:id`

### Non-direct-write fields

Do not send these as authoritative write fields for employee detail:

- `department_name`
- `position_title`
- `manager_name`

They are display/derived fields, not canonical write targets for this route.

### Reference fields

These are reference writes:

- `department_id`
- `position_id`
- `manager_employee_id`

### PATCH response as view model

- PATCH response cannot be used as the employee detail view model
- the UI must refetch `GET /api/hr/employees/:id` after a successful PATCH if view mode should reflect current data

## 5. Error Matrix

| HTTP | Runtime code | Meaning |
| --- | --- | --- |
| `400` | `INVALID_REQUEST` | body had no allowlisted writable fields |
| `400` | `INVALID_EMPLOYMENT_STATUS` | `employment_status` not in allowed runtime set |
| `400` | `INVALID_MANAGER_REFERENCE` | manager self-reference, manager not found, or manager cycle detected |
| `401` | `UNAUTHORIZED` | missing bearer token, invalid token, or no auth user resolved |
| `403` | `SCOPE_FORBIDDEN` | caller lacks writable scope |
| `403` | `PREVIEW_READ_ONLY` | preview override is active and read-only |
| `404` | `EMPLOYEE_NOT_FOUND` | employee row not found by `employees.id` in resolved scope |
| `500` | `INTERNAL_ERROR` | manager validation read failed or employee update failed |

### Common runtime caveats

- invalid `department_id` or `position_id` may surface as `500 INTERNAL_ERROR` because the route does not normalize foreign-key errors into route-specific `400` codes
- invalid `employment_type` may also surface as `500 INTERNAL_ERROR` if the database rejects the write

## 6. Smoke Examples

### Success request

```bash
curl -sS -X PATCH \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"manager_employee_id":"71000000-0000-0000-0000-000000000102","preferred_locale":"ja"}' \
  "http://localhost:3000/api/hr/employees/71000000-0000-0000-0000-000000000104?org_id=10000000-0000-0000-0000-000000000002&company_id=20000000-0000-0000-0000-000000000002&environment_type=demo"
```

Expected:

- `200`
- `schema_version = hr.employee.update.v1`
- `data.employee_id` equals the target UUID

### Common failure response

```json
{
  "schema_version": "hr.employee.update.v1",
  "data": {},
  "meta": {
    "request_id": "44444444-4444-4444-4444-444444444444",
    "timestamp": "2026-04-18T00:00:00.000Z"
  },
  "error": {
    "code": "INVALID_REQUEST",
    "message": "No updatable fields provided",
    "details": null
  }
}
```

## 7. Debug Playbook

- If the UI looks unchanged after PATCH, check whether the page tried to use the PATCH response as a detail model. It should not.
- If `manager_employee_id` fails, confirm the target manager exists in the same resolved scope and does not create a cycle.
- If the route returns `401`, check the bearer token and `Authorization` header first.
- If the route returns `404`, confirm the path param is the employee UUID, not `employee_code`.
- If data was written but not displayed, compare the PATCH acknowledgement with the GET detail read model and confirm the UI refetched the GET route.
