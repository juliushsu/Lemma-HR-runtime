# `GET / PATCH /api/settings/holiday-calendar` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `PATCH`
- path: `/api/settings/holiday-calendar`
- read schema version: `holiday_calendar.settings.v1`
- write schema version: `holiday_calendar.settings.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required

## 2. Canonical Runtime Rule

This is an organization settings family.

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- selected context is resolved server-side
- current company scope comes from selected context plus authenticated JWT
- frontend must not send `org_id`, `company_id`, `branch_id`, or `environment_type` as truth

## 3. Phase 1 Scope

This family governs company-level holiday calendar settings and scoped secondary-calendar adoption metadata.

Phase 1 supports:

- one primary calendar
- multiple secondary calendars
- selected-secondary adoption
- scope targeting for:
  - `company`
  - `location`
  - `employee_group`

Phase 1 does not implement:

- department-scoped write
- employee-specific write
- government API sync
- automatic AI merge
- auto payroll or attendance mutation

## 4. Allowed Roles

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Phase 1 read roles should initially match the same organization settings family.

## 5. Canonical Data Model

Phase 1 settings response should include:

| Field | Type | Notes |
| --- | --- | --- |
| `org_id` | `uuid` | selected context scope |
| `company_id` | `uuid` | selected context scope |
| `primary_calendar` | `object` | one statutory baseline calendar |
| `secondary_calendars` | `array` | zero to many discretionary imported calendars |
| `policy_mode` | `string` | conflict / adoption governance mode |
| `scope_support` | `object` | supported scope classes and deferred classes |
| `consumption_boundary` | `object` | downstream ownership summary |

### `primary_calendar`

Required fields:

- `jurisdiction_code`
- `calendar_code`
- `source_type`
- `legal_basis_strength`

Phase 1 recommended values:

- `source_type = statutory_national_calendar`
- `legal_basis_strength = statutory_minimum`

### `secondary_calendars[]`

Each item should include:

- `calendar_id`
- `jurisdiction_code`
- `calendar_code`
- `source_type`
- `adoption_mode`
- `selection_mode`
- `selected_holiday_codes`
- `scope_type`
- `scope_refs`
- `governance_strength`
- `priority_rank`
- `enabled`

Allowed Phase 1 `scope_type` values:

- `company`
- `location`
- `employee_group`

Reserved / deferred values:

- `department`
- `employee`

Allowed Phase 1 `adoption_mode` values:

- `disabled`
- `selected_holidays_only`
- `full_calendar_reference`

Allowed Phase 1 `selection_mode` values:

- `all_source_holidays`
- `selected_codes_only`

### `policy_mode`

Supported canonical values:

- `primary_only`
- `primary_plus_selected_secondary`
- `union_observed_days`
- `scope_based_override`

Phase 1 supported modes:

- `primary_only`
- `primary_plus_selected_secondary`

Phase 1 constrained mode:

- `scope_based_override`
  - only as scoped addition logic
  - not as statutory-primary cancellation logic

Deferred:

- `union_observed_days` as a production policy mode

### `scope_support`

Required fields:

- `company`
- `location`
- `employee_group`
- `department`
- `employee`

Recommended values:

- `company = supported`
- `location = supported`
- `employee_group = supported`
- `department = deferred`
- `employee = deferred`

### `consumption_boundary`

Required fields:

- `leave_policy_mode`
- `attendance_policy_mode`
- `payroll_mode`
- `legal_governance_mode`

Recommended values:

- `leave_policy_mode = consumes_effective_observed_days`
- `attendance_policy_mode = consumes_non_working_day_baseline`
- `payroll_mode = consumes_holiday_classification_only`
- `legal_governance_mode = consumes_statutory_vs_discretionary_boundary`

## 6. `GET /api/settings/holiday-calendar`

### Purpose

Return canonical holiday calendar governance settings for the selected company scope.

### Success example

```json
{
  "schema_version": "holiday_calendar.settings.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "primary_calendar": {
      "jurisdiction_code": "TW",
      "calendar_code": "tw_statutory_public_holidays",
      "source_type": "statutory_national_calendar",
      "legal_basis_strength": "statutory_minimum"
    },
    "secondary_calendars": [
      {
        "calendar_id": "hq-jp",
        "jurisdiction_code": "JP",
        "calendar_code": "jp_public_holidays",
        "source_type": "parent_company_country",
        "adoption_mode": "selected_holidays_only",
        "selection_mode": "selected_codes_only",
        "selected_holiday_codes": [
          "new_year",
          "foundation_day"
        ],
        "scope_type": "employee_group",
        "scope_refs": [
          "jp-expat-group"
        ],
        "governance_strength": "company_discretionary_benefit",
        "priority_rank": 10,
        "enabled": true
      }
    ],
    "policy_mode": "primary_plus_selected_secondary",
    "scope_support": {
      "company": "supported",
      "location": "supported",
      "employee_group": "supported",
      "department": "deferred",
      "employee": "deferred"
    },
    "consumption_boundary": {
      "leave_policy_mode": "consumes_effective_observed_days",
      "attendance_policy_mode": "consumes_non_working_day_baseline",
      "payroll_mode": "consumes_holiday_classification_only",
      "legal_governance_mode": "consumes_statutory_vs_discretionary_boundary"
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-22T12:00:00.000Z"
  },
  "error": null
}
```

## 7. `PATCH /api/settings/holiday-calendar`

### Purpose

Update company holiday calendar governance settings in the selected company scope only.

### Writable fields

Request body may include:

- `primary_calendar`
- `secondary_calendars`
- `policy_mode`

At least one writable field must be provided.

### Validation rules

- body must be valid JSON
- exactly one primary calendar must remain configured after patch
- `policy_mode` must be one of the allowed values
- each secondary calendar must declare:
  - `scope_type`
  - `adoption_mode`
  - `selection_mode`
  - `enabled`
- secondary calendars may not remove the primary legal baseline
- unsupported scope fields must not be treated as authority inputs

### Phase 1 write behavior

Canonical behavior:

1. resolve actor from JWT
2. resolve selected context and writable company scope
3. load current holiday-calendar settings row in scope
4. apply provided company-level holiday governance fields only
5. do not mutate leave, attendance, payroll, or legal-governance result tables directly
6. return one canonical holiday-calendar payload

## 8. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not writable by current actor |
| `400` | `INVALID_REQUEST` | invalid JSON or invalid field type/value |
| `400` | `PRIMARY_CALENDAR_REQUIRED` | write would leave the company without a primary calendar |
| `400` | `UNSUPPORTED_SCOPE_TYPE` | unsupported scope type in Phase 1 write |
| `409` | `POLICY_MODE_NOT_ALLOWED` | requested policy mode is not active in Phase 1 |
| `404` | `COMPANY_NOT_FOUND` | selected company cannot be resolved in current scope |
| `500` | `INTERNAL_ERROR` | failed to load or update holiday calendar settings |

## 9. Non-goals

This Phase 1 contract does not do:

- holiday source crawling
- government API pull
- employee-specific override write
- department-level override write
- AI auto-merge
- attendance reschedule automation
- payroll auto-posting
- legal adoption action execution
