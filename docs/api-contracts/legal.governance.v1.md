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
- checks list: `legal.governance_checks.list.v1`
- check detail: `legal.governance_checks.detail.v1`
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

- `domain`
- `jurisdiction_code`
- `check_type`
- `target_object_type`
- `severity`
- `status`
- `page`
- `page_size`

### Required list item fields

- `id`
- `domain`
- `check_type`
- `target_object_type`
- `target_object_id`
- `jurisdiction_code`
- `rule_strength`
- `title`
- `statutory_minimum`
- `company_current_value`
- `ai_suggested_value`
- `deviation_type`
- `severity`
- `company_decision_status`
- `impact_domain`
- `reason_summary`
- `source_ref`
- `created_by_source`
- `created_at`
- `updated_at`

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

Allowed `company_decision_status` values:

- `pending_review`
- `adopted`
- `kept_current`
- `acknowledged_risk`

Allowed `impact_domain` values:

- `leave`
- `attendance`
- `payroll`
- `contract`
- `insurance`

Allowed `created_by_source` values:

- `ai_scan`
- `manual_trigger`
- `scheduled_job`

### Success example

```json
{
  "schema_version": "legal.governance_checks.list.v1",
  "data": {
    "items": [
      {
        "id": "11111111-1111-1111-1111-111111111111",
        "domain": "leave",
        "check_type": "leave_policy",
        "target_object_type": "company_leave_policy",
        "target_object_id": "natural-disaster-leave-policy",
        "jurisdiction_code": "TW",
        "rule_strength": "mandatory_minimum",
        "title": "天然災害假給薪政策低於建議值",
        "statutory_minimum": {
          "summary": "不得直接視為曠職"
        },
        "company_current_value": {
          "summary": "公司目前設定為 unpaid"
        },
        "ai_suggested_value": {
          "summary": "建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"
        },
        "deviation_type": "below_recommended",
        "severity": "medium",
        "company_decision_status": "pending_review",
        "impact_domain": "leave",
        "reason_summary": "目前公司規則可能把天災假與一般缺勤混同，存在治理風險",
        "source_ref": {
          "label": "天然災害出勤管理及工資給付要點",
          "effective_from": "2025-09-19"
        },
        "created_by_source": "ai_scan",
        "created_at": "2026-04-21T10:00:00Z",
        "updated_at": "2026-04-21T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 1
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

### Query semantics

- `status=all` means no `company_decision_status` filter
- `org_id` / `company_id` / `environment_type` must not be treated as authority inputs from frontend
- effective scope is resolved from bearer JWT + selected context

## 8. `GET /api/legal/governance-checks/:id`

### Purpose

Return one governance comparison item within the selected company scope.

### Required detail fields

- `item.id`
- `item.domain`
- `item.check_type`
- `item.target_object_type`
- `item.target_object_id`
- `item.jurisdiction_code`
- `item.rule_strength`
- `item.title`
- `item.statutory_minimum`
- `item.company_current_value`
- `item.ai_suggested_value`
- `item.deviation_type`
- `item.severity`
- `item.company_decision_status`
- `item.impact_domain`
- `item.reason_summary`
- `item.source_ref`
- `item.created_by_source`
- `item.created_at`
- `item.updated_at`

### Detail success example

```json
{
  "schema_version": "legal.governance_checks.detail.v1",
  "data": {
    "item": {
      "id": "11111111-1111-1111-1111-111111111111",
      "domain": "leave",
      "check_type": "leave_policy",
      "target_object_type": "company_leave_policy",
      "target_object_id": "natural-disaster-leave-policy",
      "jurisdiction_code": "TW",
      "rule_strength": "mandatory_minimum",
      "title": "天然災害假給薪政策低於建議值",
      "statutory_minimum": {
        "summary": "不得直接視為曠職"
      },
      "company_current_value": {
        "summary": "公司目前設定為 unpaid"
      },
      "ai_suggested_value": {
        "summary": "建議保留 unpaid，但不得扣全勤，並需明確標註為天災假"
      },
      "deviation_type": "below_recommended",
      "severity": "medium",
      "company_decision_status": "pending_review",
      "impact_domain": "leave",
      "reason_summary": "目前公司規則可能把天災假與一般缺勤混同，存在治理風險",
      "source_ref": {
        "label": "天然災害出勤管理及工資給付要點",
        "effective_from": "2025-09-19"
      },
      "created_by_source": "ai_scan",
      "created_at": "2026-04-21T10:00:00Z",
      "updated_at": "2026-04-21T10:00:00Z"
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

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
