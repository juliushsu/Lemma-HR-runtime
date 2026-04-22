# Holiday Calendar Preview Contract v1

## 1. Endpoint Metadata

Phase 1 preview family endpoints:

- `GET /api/settings/holiday-calendar/preview`

Reserved but deferred:

- `GET /api/settings/holiday-calendar/preview/:date`
- `GET /api/settings/holiday-calendar/preview/:employee_id`

Schema versions:

- preview: `holiday_calendar.preview.v1`

## 2. Canonical Runtime Rule

Canonical frontend-facing runtime must be:

- `Railway`

Preview scope interpretation:

- company scope is resolved from selected context + JWT
- frontend must not send `org_id`, `company_id`, or `environment_type` as truth
- preview may accept optional filters, but scope truth remains server-owned

## 3. Purpose

Return explanation-first resolved holiday outcomes for the selected company scope before downstream leave / attendance / payroll / legal consumers apply them.

Preview exists to answer:

- which dates are effectively observed days
- which source calendars contributed
- which scope received the holiday
- whether the day is statutory or discretionary
- how a conflict was resolved

## 4. Phase 1 Input Model

Phase 1 preview reads from:

- primary calendar settings
- secondary calendar settings
- scoped adoption metadata
- selected holiday codes
- conflict policy mode

Phase 1 preview does not require:

- live government API sync
- employee-specific override data
- payroll or attendance write state

## 5. Query Parameters

Optional query parameters:

- `year`
- `month`
- `scope_type`
- `scope_ref`

Allowed Phase 1 `scope_type` filters:

- `company`
- `location`
- `employee_group`

If omitted:

- preview defaults to company-wide effective view

## 6. Core Output Model

Phase 1 preview outputs should include:

- `primary_calendar`
- `secondary_calendars`
- `policy_mode`
- `items[]`
- `warnings[]`

Each `items[]` row should include:

- `date`
- `effective_day_status`
- `holiday_type`
- `governance_class`
- `source_labels`
- `scope_type`
- `scope_refs`
- `conflict_resolution`
- `downstream_hints`

### `effective_day_status`

Recommended values:

- `observed_holiday`
- `working_day`
- `observed_scope_holiday`

### `holiday_type`

Allowed canonical values:

- `statutory_public_holiday`
- `company_observed_holiday`
- `imported_secondary_holiday`
- `selected_cultural_welfare_holiday`

### `governance_class`

Allowed canonical values:

- `statutory_minimum`
- `company_discretionary_benefit`
- `group_sync_observed_day`
- `scope_specific_discretionary_day`

### `conflict_resolution`

Recommended fields:

- `mode`
- `primary_result`
- `secondary_result`
- `effective_result`
- `explanation`

### `downstream_hints`

Recommended fields:

- `leave_policy_effect`
- `attendance_effect`
- `payroll_effect`
- `legal_governance_effect`

These are preview hints only, not executable side effects.

## 7. `GET /api/settings/holiday-calendar/preview`

### Success example

```json
{
  "schema_version": "holiday_calendar.preview.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "year": 2026,
    "month": 4,
    "primary_calendar": {
      "jurisdiction_code": "TW",
      "calendar_code": "tw_statutory_public_holidays"
    },
    "secondary_calendars": [
      {
        "calendar_id": "thai-cultural-group",
        "jurisdiction_code": "TH",
        "scope_type": "employee_group",
        "scope_refs": [
          "thai-factory-group"
        ],
        "selection_mode": "selected_codes_only"
      }
    ],
    "policy_mode": "primary_plus_selected_secondary",
    "items": [
      {
        "date": "2026-04-13",
        "effective_day_status": "observed_scope_holiday",
        "holiday_type": "selected_cultural_welfare_holiday",
        "governance_class": "scope_specific_discretionary_day",
        "source_labels": [
          "songkran_festival"
        ],
        "scope_type": "employee_group",
        "scope_refs": [
          "thai-factory-group"
        ],
        "conflict_resolution": {
          "mode": "primary_plus_selected_secondary",
          "primary_result": "working_day",
          "secondary_result": "selected_holiday",
          "effective_result": "observed_scope_holiday",
          "explanation": "Secondary selected holiday was explicitly adopted for the targeted employee group."
        },
        "downstream_hints": {
          "leave_policy_effect": "display_as_group_observed_holiday",
          "attendance_effect": "treat_as_non_working_day_for_scope",
          "payroll_effect": "requires_company_policy_pay_classification",
          "legal_governance_effect": "company_discretionary_not_statutory_minimum"
        }
      }
    ],
    "warnings": []
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-22T12:00:00.000Z"
  },
  "error": null
}
```

## 8. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not readable by current actor |
| `400` | `INVALID_REQUEST` | invalid year/month or unsupported scope filter |
| `404` | `COMPANY_NOT_FOUND` | selected company cannot be resolved in current scope |
| `500` | `CONFIG_MISSING` | required holiday-calendar settings substrate missing |
| `500` | `INTERNAL_ERROR` | failed to compute preview |

## 9. Non-goals

This Phase 1 preview contract does not do:

- attendance rescheduling
- payroll run execution
- legal decision mutation
- employee-level routing
- automatic source sync
