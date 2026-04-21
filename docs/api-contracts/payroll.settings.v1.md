# `GET / PATCH /api/payroll/settings` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `PATCH`
- path: `/api/payroll/settings`
- read schema version: `payroll.settings.v1`
- write schema version: `payroll.settings.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required

## 2. Canonical Runtime Rule

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- selected context is resolved server-side
- current company scope comes from selected context plus authenticated JWT
- frontend must not send `org_id`, `company_id`, `branch_id`, or `environment_type` as truth

## 3. Phase 1 Scope

This contract governs company-level payroll calculation settings only.

Phase 1 does not implement:

- employee-level compensation write
- location-level payroll override write
- payroll run / payroll closing settings

Phase 1 scope rule:

1. resolve actor from JWT
2. resolve selected company context server-side
3. require writable company scope
4. reject any client-sent scope override as authority input

## 4. Allowed Roles

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Phase 1 read roles should initially match the same HR / admin family:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

## 5. Canonical Data Model

Phase 1 settings response should include:

| Field | Type | Notes |
| --- | --- | --- |
| `org_id` | `uuid` | selected context scope |
| `company_id` | `uuid` | selected context scope |
| `jurisdiction_code` | `string` | Phase 1 default `TW` |
| `currency_code` | `string` | Phase 1 default `TWD` |
| `preview_mode` | `string` | Phase 1 fixed value `preview_only` |
| `payroll_settings` | `object` | company-level payroll calculation settings |
| `earnings_component_families` | `array` | canonical earnings catalog |
| `deduction_component_families` | `array` | canonical deductions catalog |
| `leave_compensation_rules` | `array` | payroll-facing leave pay matrix |
| `natural_disaster_leave_policy` | `object` | Taiwan-first disaster-pay policy |
| `override_model` | `object` | company / employee / location boundary metadata |

### `payroll_settings`

Recommended fields:

- `jurisdiction_code`
- `currency_code`
- `attendance_bonus_policy`
- `leave_policy_mode`
- `preview_mode`

### `attendance_bonus_policy`

Recommended fields:

- `enabled`
- `protected_leave_types`
- `protected_absence_types`
- `notes`

### `earnings_component_families[]`

Each item should include at least:

- `family_code`
- `recurrence_type`
- `enabled`
- `employee_income_included`
- `employer_cost_included`

### `deduction_component_families[]`

Each item should include at least:

- `family_code`
- `enabled`
- `employee_income_included`
- `employer_cost_included`

### `leave_compensation_rules[]`

Each item should include at least:

- `leave_policy_key`
- `jurisdiction_code`
- `statutory_leave_type`
- `company_policy_leave_type`
- `compensation_mode`
- `compensation_ratio`
- `funding_source`
- `employer_cost_included`
- `employee_income_included`
- `excluded_from_attendance_bonus_deduction`

### `natural_disaster_leave_policy`

Required fields:

- `compensation_mode`
- `compensation_ratio`
- `funding_source`
- `excluded_from_attendance_bonus_deduction`
- `warning_note`

Allowed `compensation_mode` values:

- `unpaid`
- `paid_partial`
- `paid_full`

Allowed `funding_source` values:

- `employer_paid`
- `government_paid`
- `social_insurance_paid`
- `mixed`

### `override_model`

Required fields:

- `company_default_mode`
- `employee_override_mode`
- `location_override_mode`

Recommended values:

- `company_default_mode = canonical`
- `employee_override_mode = missing`
- `location_override_mode = deferred`

## 6. `GET /api/payroll/settings`

### Purpose

Return canonical payroll calculation settings for the selected company scope.

### Success example

```json
{
  "schema_version": "payroll.settings.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "jurisdiction_code": "TW",
    "currency_code": "TWD",
    "preview_mode": "preview_only",
    "payroll_settings": {
      "attendance_bonus_policy": {
        "enabled": true,
        "protected_leave_types": [
          "annual_leave",
          "marriage_leave",
          "bereavement_leave",
          "family_care_leave",
          "natural_disaster_leave"
        ]
      },
      "leave_policy_mode": "jurisdiction_first"
    },
    "earnings_component_families": [
      {
        "family_code": "base_salary",
        "recurrence_type": "recurring_fixed",
        "enabled": true,
        "employer_cost_included": true,
        "employee_income_included": true
      }
    ],
    "deduction_component_families": [
      {
        "family_code": "leave_deduction",
        "enabled": true,
        "employer_cost_included": true,
        "employee_income_included": true
      }
    ],
    "leave_compensation_rules": [
      {
        "leave_policy_key": "sick_leave",
        "jurisdiction_code": "TW",
        "statutory_leave_type": "sick_leave",
        "company_policy_leave_type": null,
        "compensation_mode": "paid_partial",
        "compensation_ratio": 0.5,
        "funding_source": "mixed",
        "employer_cost_included": true,
        "employee_income_included": true,
        "excluded_from_attendance_bonus_deduction": false
      }
    ],
    "natural_disaster_leave_policy": {
      "compensation_mode": "unpaid",
      "compensation_ratio": 0.0,
      "funding_source": "employer_paid",
      "excluded_from_attendance_bonus_deduction": true,
      "warning_note": "Natural-disaster non-attendance must not be treated as unexcused absence."
    },
    "override_model": {
      "company_default_mode": "canonical",
      "employee_override_mode": "missing",
      "location_override_mode": "deferred"
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

## 7. `PATCH /api/payroll/settings`

### Purpose

Update company-level payroll calculation settings inside the selected company scope only.

### Writable fields

Phase 1 writable fields may include:

- `jurisdiction_code`
- `currency_code`
- `attendance_bonus_policy`
- `leave_compensation_rules`
- `natural_disaster_leave_policy`

At least one writable field must be provided.

### Validation Rules

- body must be valid JSON
- `jurisdiction_code` must be an uppercase jurisdiction code
- `currency_code` must be an uppercase currency code
- `compensation_mode` must be one of:
  - `unpaid`
  - `paid_partial`
  - `paid_full`
- `compensation_ratio` must be between `0.0` and `1.0`
- `funding_source` must be one of:
  - `employer_paid`
  - `government_paid`
  - `social_insurance_paid`
  - `mixed`
- `excluded_from_attendance_bonus_deduction` must be boolean
- unsupported keys must not be treated as scope or authority inputs

### Phase 1 Write Behavior

Canonical behavior:

1. resolve actor from JWT
2. resolve selected context and writable company scope
3. load current payroll settings row in scope
4. update company-level payroll policy only
5. return one canonical payroll settings payload

### Success example

```json
{
  "schema_version": "payroll.settings.update.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "jurisdiction_code": "TW",
    "currency_code": "TWD",
    "preview_mode": "preview_only",
    "natural_disaster_leave_policy": {
      "compensation_mode": "paid_partial",
      "compensation_ratio": 0.5,
      "funding_source": "employer_paid",
      "excluded_from_attendance_bonus_deduction": true,
      "warning_note": "Natural-disaster non-attendance must not be treated as unexcused absence."
    },
    "override_model": {
      "company_default_mode": "canonical",
      "employee_override_mode": "missing",
      "location_override_mode": "deferred"
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

## 8. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not writable by current actor |
| `400` | `INVALID_REQUEST` | invalid JSON, no writable field, or invalid field type/value |
| `404` | `PAYROLL_SETTINGS_NOT_FOUND` | policy substrate has not been initialized for the selected company |
| `500` | `CONFIG_MISSING` | required payroll settings substrate missing |
| `500` | `INTERNAL_ERROR` | failed to load or update payroll settings |

## 9. Non-goals

This Phase 1 contract does not do:

- payroll run / closing
- payslip issuance
- tax withholding output
- bank export
- accounting integration
- employee-level compensation write
- location-level payroll override write
