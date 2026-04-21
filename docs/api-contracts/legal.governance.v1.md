# Legal Governance Contract v1

## 1. Canonical Families

Phase 1 legal governance families:

- `GET /api/legal/updates`
- `GET /api/legal/updates/:id`
- `GET /api/legal/governance-checks`
- `GET /api/legal/governance-checks/:id`

Reserved Phase 1 action family:

- `POST /api/legal/governance-checks/:id/adopt-suggestion`
- `POST /api/legal/governance-checks/:id/keep-current`
- `POST /api/legal/governance-checks/:id/acknowledge-warning`

Reserved analysis family:

- `POST /api/legal/analyze/document`
- `POST /api/legal/analyze/policy`

Schema versions:

- updates list: `legal.update.list.v1`
- update detail: `legal.update.detail.v1`
- checks list: `legal.governance_check.list.v1`
- check detail: `legal.governance_check.detail.v1`
- analysis result: `legal.analysis.result.v1`

## 2. Canonical Runtime Rule

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- actor is resolved from JWT
- company scope is resolved from selected context
- legal comparison and adoption orchestration remain app-owned
- model control is never sourced from frontend payloads

## 3. Applicability Model

All legal updates and governance checks should support:

- `jurisdiction_country_code`
- `jurisdiction_region_code`
- `applicable_scope_type`
- `effective_from`
- `effective_to`
- `source_ref`
- `source_type`

Allowed `applicable_scope_type` values:

- `company`
- `location`
- `employee_group`

Allowed `source_type` values:

- `official_law`
- `administrative_guidance`
- `internal_policy`
- `other`

## 4. Rule Strength Model

Each update or comparison item should classify legal force using:

- `mandatory_minimum`
- `recommended_best_practice`
- `company_discretion`

This field prevents advisory AI guidance from being misrepresented as binding law.

## 5. `GET /api/legal/updates`

### Purpose

Return legal update events visible to the selected company scope.

### Query examples

Optional query parameters:

- `jurisdiction_country_code`
- `domain`
- `severity`
- `effective_status`
- `page`
- `page_size`

### List item shape

Each update item should contain at least:

- `id`
- `update_type`
- `domain`
- `jurisdiction_country_code`
- `jurisdiction_region_code`
- `source_ref`
- `source_type`
- `old_summary`
- `new_summary`
- `effective_from`
- `effective_to`
- `effective_status`
- `rule_strength`
- `affected_domains`
- `risk_severity`
- `impacts_current_company_policy`

`affected_domains` should allow values such as:

- `leave`
- `payroll`
- `attendance`
- `contract`
- `insurance`

### Success example

```json
{
  "schema_version": "legal.update.list.v1",
  "data": {
    "items": [
      {
        "id": "upd_001",
        "update_type": "law_revision",
        "domain": "leave",
        "jurisdiction_country_code": "TW",
        "jurisdiction_region_code": null,
        "source_ref": "MOL-FL049533-2025-09-19",
        "source_type": "administrative_guidance",
        "old_summary": "Prior natural-disaster attendance guidance baseline.",
        "new_summary": "Updated guidance adds commuting-assistance emphasis and wage guidance note.",
        "effective_from": "2025-09-19",
        "effective_to": null,
        "effective_status": "effective",
        "rule_strength": "recommended_best_practice",
        "affected_domains": ["attendance", "leave", "payroll"],
        "risk_severity": "medium",
        "impacts_current_company_policy": true
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

## 6. `GET /api/legal/updates/:id`

### Purpose

Return one legal update detail record.

### Required detail fields

- `id`
- `jurisdiction`
- `source`
- `old_summary`
- `new_summary`
- `diff_summary`
- `effective_from`
- `effective_status`
- `rule_strength`
- `affected_domains`
- `recommended_follow_up`

## 7. `GET /api/legal/governance-checks`

### Purpose

Return legal governance comparison results for the selected company scope.

### Query examples

Optional query parameters:

- `check_type`
- `target_object_type`
- `severity`
- `human_review_status`
- `created_by_source`
- `page`
- `page_size`

### Required list item fields

- `id`
- `check_type`
- `target_object_type`
- `target_object_id`
- `jurisdiction_code`
- `statutory_minimum`
- `company_current_value`
- `ai_suggested_value`
- `deviation_type`
- `severity`
- `reason_summary`
- `human_review_status`
- `created_by_source`
- `acknowledged_risk`

Allowed `check_type` values:

- `leave_policy`
- `payroll_policy`
- `attendance_policy`
- `contract_clause`
- `insurance_recommendation`

Allowed `severity` values:

- `info`
- `low`
- `medium`
- `high`
- `critical`

Allowed `human_review_status` values:

- `pending`
- `reviewed`
- `adopted`
- `dismissed`

Allowed `created_by_source` values:

- `ai_scan`
- `manual_trigger`
- `scheduled_job`

### Success example

```json
{
  "schema_version": "legal.governance_check.list.v1",
  "data": {
    "items": [
      {
        "id": "check_001",
        "check_type": "leave_policy",
        "target_object_type": "leave_policy_profile",
        "target_object_id": "leave_profile_001",
        "jurisdiction_code": "TW",
        "statutory_minimum": {
          "sick_leave": {
            "compensation_mode": "paid_partial",
            "compensation_ratio": 0.5
          }
        },
        "company_current_value": {
          "sick_leave": {
            "compensation_mode": "unpaid"
          }
        },
        "ai_suggested_value": {
          "sick_leave": {
            "compensation_mode": "paid_partial",
            "compensation_ratio": 0.5
          }
        },
        "deviation_type": "below_statutory_minimum",
        "severity": "high",
        "reason_summary": "Current sick-leave treatment appears below statutory minimum.",
        "human_review_status": "pending",
        "created_by_source": "scheduled_job",
        "acknowledged_risk": false
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

## 8. `GET /api/legal/governance-checks/:id`

### Purpose

Return one governance check with full comparison context.

### Required detail fields

- `id`
- `check_type`
- `target_object_type`
- `target_object_id`
- `jurisdiction`
- `statutory_minimum`
- `company_current_value`
- `ai_suggested_value`
- `deviation_summary`
- `severity`
- `reason_summary`
- `human_review_status`
- `created_by_source`
- `acknowledged_risk`
- `override_reason`
- `approved_by`
- `approved_at`

## 9. Reserved Adoption Actions

Phase 1 should reserve these actions even if implementation is deferred:

- `POST /api/legal/governance-checks/:id/adopt-suggestion`
- `POST /api/legal/governance-checks/:id/keep-current`
- `POST /api/legal/governance-checks/:id/acknowledge-warning`

### Intended behavior

`adopt-suggestion`

- records that a human adopted the suggested direction
- may later trigger downstream policy update workflows
- does not imply direct auto-write in Phase 1

`keep-current`

- records that the company intentionally keeps the current value
- should require `override_reason`
- should preserve risk acknowledgement fields

`acknowledge-warning`

- records that the warning was seen and accepted
- does not imply adoption

## 10. Reserved Analysis Family

Reserved Phase 1 analysis targets:

- labor consulting agreement
- employment contract
- fixed-term / contract employment agreement
- leave policy
- internal HR policy
- attendance policy
- payroll policy

### Reserved routes

- `POST /api/legal/analyze/document`
- `POST /api/legal/analyze/policy`

### Minimum analysis output shape

If implemented later, the result should include at least:

- `analysis_target_type`
- `jurisdiction_code`
- `source_ref`
- `summary`
- `governance_findings[]`
- `risk_severity`
- `suggested_actions[]`
- `requires_human_review`

## 11. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | actor cannot access this company-scoped legal governance data |
| `404` | `LEGAL_UPDATE_NOT_FOUND` | requested update does not exist in scope |
| `404` | `GOVERNANCE_CHECK_NOT_FOUND` | requested governance check does not exist in scope |
| `409` | `CHECK_ALREADY_RESOLVED` | an adoption action cannot be repeated |
| `400` | `INVALID_REQUEST` | malformed payload or missing required action fields |
| `500` | `CONFIG_MISSING` | required legal-governance substrate missing |
| `500` | `INTERNAL_ERROR` | failed to read or process governance object |

## 12. Non-goals

This Phase 1 legal governance contract does not do:

- autonomous legal update execution
- direct automatic policy overwrite
- customer-controlled model switching
- full country-by-country law engine
- full document clause generation
- insurer pricing or policy API integration
