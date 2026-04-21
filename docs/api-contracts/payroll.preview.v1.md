# Payroll Preview Contract v1

## 1. Endpoint Metadata

Phase 1 preview family endpoints:

- `GET /api/payroll/preview`
- `GET /api/payroll/preview/:employee_id`
- `GET /api/payroll/preview/:employee_id/breakdown`

Reserved but deferred:

- `GET /api/payroll/components`

Schema versions:

- preview list: `payroll.preview.list.v1`
- preview detail: `payroll.preview.detail.v1`
- preview breakdown: `payroll.preview.breakdown.v1`

## 2. Canonical Runtime Rule

Canonical frontend-facing runtime must be:

- `Railway`

Preview scope interpretation:

- company scope is resolved from selected context + JWT
- frontend must not send `org_id`, `company_id`, or `environment_type` as truth
- `employee_id` in the path is a scoped target, not a free global lookup

## 3. Phase 1 Input Model

Phase 1 preview reads from:

- approved leave data
- attendance summary or attendance events
- approved attendance corrections only
- payroll settings policy
- employee compensation settings when available

Known Phase 1 substrate status:

- approved leave data: `available`
- attendance events / summary: `partial`
- approved attendance corrections: `available`
- employee compensation settings: `missing`
- manual payroll adjustments: `deferred`

Canonical rule:

- missing inputs must become `warnings[]`
- preview must not silently assume completed compensation data when it is absent

## 4. Core Output Model

Phase 1 preview outputs must include:

- `gross_pay`
- `total_earnings`
- `total_deductions`
- `net_pay`
- `breakdown_items[]`
- `policy_applied[]`
- `warnings[]`

Extended preview outputs that belong to the canonical model:

- `gross_pay_employer_basis`
- `leave_compensation_employer_paid`
- `leave_compensation_non_employer_paid`
- `employee_total_visible_income`
- `net_pay_employer_payable`

Phase 1 implementation rule:

- these extended fields may be `null` when upstream data is missing
- they should not be removed from the preview model

## 5. `GET /api/payroll/preview`

### Purpose

Return company-scoped payroll preview summary rows for in-scope employees.

### Query parameters

Optional query parameters:

- `period=YYYY-MM`
- `keyword`
- `page`
- `page_size`

### Success example

```json
{
  "schema_version": "payroll.preview.list.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "period": "2026-04",
    "items": [
      {
        "employee_id": "33000000-0000-0000-0000-000000000001",
        "employee_code": "TW-EMP-0001",
        "employee_name": "Lin Pinyu",
        "gross_pay": null,
        "total_earnings": null,
        "total_deductions": null,
        "net_pay": null,
        "warnings_count": 1,
        "preview_status": "incomplete_missing_compensation"
      }
    ]
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

### Phase 1 list rule

`GET /api/payroll/preview` may ship after detail if the team needs to reduce initial route count.

But if implemented, it must stay in the same canonical preview family.

## 6. `GET /api/payroll/preview/:employee_id`

### Purpose

Return one employee-scoped payroll preview summary for the selected company scope and period.

### Success example

```json
{
  "schema_version": "payroll.preview.detail.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "period": "2026-04",
    "employee": {
      "employee_id": "33000000-0000-0000-0000-000000000001",
      "employee_code": "TW-EMP-0001",
      "employee_name": "Lin Pinyu"
    },
    "preview": {
      "gross_pay": 52000,
      "total_earnings": 54000,
      "total_deductions": 2300,
      "net_pay": 51700,
      "gross_pay_employer_basis": 52000,
      "leave_compensation_employer_paid": 0,
      "leave_compensation_non_employer_paid": null,
      "employee_total_visible_income": null,
      "net_pay_employer_payable": 51700
    },
    "policy_applied": [
      {
        "policy_key": "sick_leave",
        "source": "leave_compensation_rules",
        "effect": "paid_partial_ratio_0_5"
      }
    ],
    "warnings": [
      {
        "code": "EMPLOYEE_COMPENSATION_SETTINGS_MISSING",
        "message": "Preview used incomplete employee compensation substrate."
      }
    ]
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

### Required success fields

- `data.employee`
- `data.preview.gross_pay`
- `data.preview.total_earnings`
- `data.preview.total_deductions`
- `data.preview.net_pay`
- `data.policy_applied[]`
- `data.warnings[]`

## 7. `GET /api/payroll/preview/:employee_id/breakdown`

### Purpose

Return explanation-first payroll preview breakdown for one employee.

### Success example

```json
{
  "schema_version": "payroll.preview.breakdown.v1",
  "data": {
    "employee": {
      "employee_id": "33000000-0000-0000-0000-000000000001",
      "employee_code": "TW-EMP-0001"
    },
    "period": "2026-04",
    "breakdown_items": [
      {
        "item_type": "earning",
        "family_code": "base_salary",
        "label": "Base Salary",
        "recurrence_type": "recurring_fixed",
        "amount": 52000,
        "funding_source": "employer_paid",
        "employer_cost_included": true,
        "employee_income_included": true
      },
      {
        "item_type": "deduction",
        "family_code": "health_insurance_employee",
        "label": "Health Insurance Employee Share",
        "amount": 1200,
        "funding_source": "employer_paid",
        "employer_cost_included": true,
        "employee_income_included": true
      }
    ],
    "policy_applied": [
      {
        "policy_key": "natural_disaster_leave_policy",
        "source": "payroll_settings",
        "effect": "excluded_from_attendance_bonus_deduction"
      }
    ],
    "warnings": []
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

### `breakdown_items[]` minimum fields

- `item_type`
- `family_code`
- `label`
- `amount`
- `funding_source`
- `employer_cost_included`
- `employee_income_included`

Optional but recommended:

- `recurrence_type`
- `source_ref`
- `calculation_note`

## 8. `GET /api/payroll/components`

Phase 1 decision:

- endpoint name is reserved
- a standalone components catalog may be deferred
- canonical explanation source in early Phase 1 remains:
  - `breakdown_items[]`
  - `policy_applied[]`

If later implemented, this route should return component-family metadata only and must not replace employee-specific breakdown.

## 9. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not readable by current actor |
| `404` | `EMPLOYEE_NOT_FOUND` | employee is not in selected company scope |
| `404` | `PAYROLL_SETTINGS_NOT_FOUND` | company payroll settings are not yet initialized |
| `409` | `PREVIEW_INPUTS_INCOMPLETE` | preview cannot produce a stable result because required inputs are missing |
| `500` | `CONFIG_MISSING` | required calculation substrate missing |
| `500` | `INTERNAL_ERROR` | failed to load or compute preview |

## 10. Non-goals

This Phase 1 preview contract does not do:

- payroll closing
- run locking
- payslip issuance
- bank export
- tax output
- accounting integration
- overtime engine
- roster-aware differential pay
- holiday premium calculation
- manual adjustment write
