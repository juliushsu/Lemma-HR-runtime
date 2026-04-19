# `GET /api/hr/employees/:id` Contract

## 1. Endpoint Metadata

- method: `GET`
- path: `/api/hr/employees/:id`
- schema_version: `hr.employee.detail.v1`
- auth requirement: `Authorization: Bearer <JWT>` required
- scope: resolved from selected context and optional `org_id` / `company_id` / `branch_id` / `environment_type` query params; caller must have readable membership in the resolved scope
- environment support:
  - deployment: current app route can run in staging or production deployment environments
  - data scope: runtime supports any membership-bound employee scope; commonly `production`, `demo`, `sandbox`
- canonical truth-source:
  - primary: `public.employees`
  - derived reads: `public.departments`, `public.positions`, `public.employees` (manager), `public.employee_assignments`

## 2. Request Contract

### Path params

| Name | Type | Required | UUID support | `employee_code` support | Runtime rule |
| --- | --- | --- | --- | --- | --- |
| `id` | `string` | yes | yes | yes | if `id` matches UUID regex, lookup uses `employees.id`; otherwise lookup uses exact `employees.employee_code` |

Notes:

- `employee_code` matching is exact runtime equality in the current route.
- The current route does not normalize case for `employee_code`.

### Query params

| Name | Type | Required | Purpose |
| --- | --- | --- | --- |
| `org_id` | `uuid` | no | scope override / disambiguation |
| `company_id` | `uuid` | no | scope override / disambiguation |
| `branch_id` | `uuid \| null` | no | branch scope narrowing |
| `environment_type` | `string` | no | scope override / disambiguation |

## 3. Response Contract

- structure: nested
- envelope: canonical `{ schema_version, data, meta, error }`

### Success example

```json
{
  "schema_version": "hr.employee.detail.v1",
  "data": {
    "employee": {
      "id": "71000000-0000-0000-0000-000000000104",
      "employee_code": "DEMO-004",
      "legal_name": "Emily Johnson",
      "preferred_name": "Emily",
      "display_name": "Emily Johnson",
      "family_name_local": "鈴木",
      "given_name_local": "花子",
      "full_name_local": "鈴木 花子",
      "family_name_latin": "Suzuki",
      "given_name_latin": "Hanako",
      "full_name_latin": "Hanako Suzuki",
      "department_name": "Demo Headquarters",
      "position_title": "HR Specialist",
      "manager_name": "佐藤 健（さとう けん）",
      "work_email": "demo.emily@lemma.local",
      "personal_email": null,
      "mobile_phone": "+886900100004",
      "nationality_code": "JP",
      "work_country_code": "JP",
      "preferred_locale": "ja",
      "timezone": "Asia/Tokyo",
      "department_id": "72000000-0000-0000-0000-000000000201",
      "position_id": "73000000-0000-0000-0000-000000000301",
      "manager_employee_id": "71000000-0000-0000-0000-000000000102",
      "employment_type": "full_time",
      "employment_status": "active",
      "hire_date": "2026-01-15",
      "termination_date": null,
      "gender_note": "female",
      "notes": "Demo employee detail sample"
    },
    "department": {
      "id": "72000000-0000-0000-0000-000000000201",
      "department_code": "DEMO-HQ",
      "department_name": "Demo Headquarters"
    },
    "position": {
      "id": "73000000-0000-0000-0000-000000000301",
      "position_code": "DEMO-HR-SPEC",
      "position_name": "HR Specialist",
      "job_level": "L2"
    },
    "manager": {
      "id": "71000000-0000-0000-0000-000000000102",
      "employee_code": "DEMO-002",
      "display_name": "佐藤 健"
    },
    "current_assignment": {
      "id": "74000000-0000-0000-0000-000000000401",
      "assignment_type": "primary",
      "effective_from": "2026-01-15",
      "effective_to": null,
      "is_current": true
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-18T00:00:00.000Z"
  },
  "error": null
}
```

### Guaranteed fields on `200`

- `schema_version`
- `data.employee`
- `data.employee.id`
- `data.employee.employee_code`
- all keys currently constructed under `data.employee`, even when their values are `null`
- `meta.request_id`
- `meta.timestamp`
- `error = null`

### Optional nullable fields

- `data.department`
- `data.position`
- `data.manager`
- `data.current_assignment`
- nullable values within `data.employee`, including:
  - `personal_email`
  - `mobile_phone`
  - `department_id`
  - `position_id`
  - `manager_employee_id`
  - `termination_date`
  - `gender_note`
  - `notes`

### Missing fields in current runtime

The current route does not return the following employee-detail fields that older detail docs may imply:

- `data.employee.gender`
- `data.employee.birth_date`
- `data.employee.emergency_contact_name`
- `data.employee.emergency_contact_phone`
- `data.employee.direct_reports_count`
- `data.employee.avatar_url`

### Derived fields

These fields are display-oriented reads, not direct writable employee master fields:

- `data.employee.department_name`
- `data.employee.position_title`
- `data.employee.manager_name`
- `data.department`
- `data.position`
- `data.manager`
- `data.current_assignment`

## 4. UI Consumption Rules

### Cross-Route Integration Rule

- `GET /api/hr/employees/:id` supports both employee UUID and exact `employee_code`
- `PATCH /api/hr/employees/:id` supports employee UUID only and does not support `employee_code`
- if the UI enters the employee detail page from GET, it must retain `data.employee.id` before attempting PATCH
- PATCH success response cannot be used as the employee detail view model
- after successful PATCH, the UI must refetch canonical `GET /api/hr/employees/:id` detail before rendering view mode
- Readdy must not infer PATCH path semantics from GET path semantics; the two routes intentionally differ
### Direct display fields

Safe to display directly from `data.employee`:

- `employee_code`
- `display_name`
- `full_name_local`
- `full_name_latin`
- `department_name`
- `position_title`
- `manager_name`
- `employment_type`
- `employment_status`
- `preferred_locale`
- `timezone`
- `hire_date`
- `work_email`
- `personal_email`
- `mobile_phone`
- `nationality_code`

### Fields that need mapping or presentation logic

- `nationality_code` -> country label in UI if localized label is desired
- `employment_status` -> human-readable status label
- `employment_type` -> human-readable employment type label
- `hire_date` / `termination_date` -> date-only presentation
- `preferred_locale` -> locale label if localized label is desired

### Reference fields

These are identifiers / references, not display labels:

- `department_id`
- `position_id`
- `manager_employee_id`

### Non-writable display fields

Do not treat these as direct write targets:

- `department_name`
- `position_title`
- `manager_name`
- all nested `department`, `position`, `manager`, `current_assignment` objects

### Adapter rules for Readdy

- this endpoint is nested, not flat
- prefer `data.employee.department_name`, not `data.department.department_name`, for the page-level employee view model
- prefer `data.employee.position_title`, not `data.position.position_name`, for the page-level employee view model
- prefer `data.employee.manager_name`, not `data.manager.display_name`, for the page-level employee view model

### Write/read rule

- this GET route is the detail read model
- if the employee is edited via `PATCH /api/hr/employees/:id`, the UI should refetch this GET route before updating view mode

## 5. Error Matrix

| HTTP | Runtime code | Meaning |
| --- | --- | --- |
| `400` | none in current GET route | no GET-specific validation branch currently emits `400` |
| `401` | `UNAUTHORIZED` | missing bearer token, invalid token, or no auth user resolved |
| `403` | `SCOPE_FORBIDDEN` | token is valid but selected / requested scope is not readable |
| `404` | `EMPLOYEE_NOT_FOUND` | no employee matched the UUID or exact `employee_code` within resolved scope |
| `500` | `INTERNAL_ERROR` | employee read failed at data layer |

## 6. Smoke Examples

### Success request

```bash
curl -sS \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  "http://localhost:3000/api/hr/employees/DEMO-004?org_id=10000000-0000-0000-0000-000000000002&company_id=20000000-0000-0000-0000-000000000002&environment_type=demo"
```

Expected:

- `200`
- `schema_version = hr.employee.detail.v1`
- `data.employee.employee_code = DEMO-004`

### Common failure response

```json
{
  "schema_version": "hr.employee.detail.v1",
  "data": {},
  "meta": {
    "request_id": "22222222-2222-2222-2222-222222222222",
    "timestamp": "2026-04-18T00:00:00.000Z"
  },
  "error": {
    "code": "EMPLOYEE_NOT_FOUND",
    "message": "Employee not found",
    "details": null
  }
}
```

## 7. Debug Playbook

- If the page is blank, first confirm the response is `200` and `data.employee` exists.
- If the page is blank but the response is populated, check whether the adapter is expecting a flat payload instead of the current nested shape.
- If the request returns `401`, check the bearer token and `Authorization` header first.
- If a value was written but is not displayed, compare the PATCH write response with this GET read model. They are different routes with different shapes.
- If `employee_code` lookup fails, verify the path param matches the stored code exactly in current runtime.
