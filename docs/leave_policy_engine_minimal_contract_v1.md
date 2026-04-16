# Leave Policy Engine Minimal Contract v1

Status: staging schema landed (`20260404220000_leave_policy_engine_minimal_schema_v1.sql`), no production change.

## A. Canonical Naming

### 1) Policy profile
- `leave_policy_profiles.id`
- `org_id`
- `company_id`
- `country_code`
- `policy_name`
- `effective_from`
- `effective_to`
- `leave_year_mode` (`calendar_year|anniversary_year|custom`)
- `holiday_mode` (`official_calendar|shift_based|hybrid`)
- `allow_cross_country_holiday_merge`
- `payroll_policy_mode` (`strict|custom`)
- `compliance_warning_enabled`
- `notes`

### 2) Leave type
- `leave_types.id`
- `leave_policy_profile_id`
- `leave_type_code` (canonical code, future `leave_requests.leave_type` should align with this)
- `display_name`
- `is_paid`
- `affects_payroll`
- `requires_attachment`
- `requires_approval`
- `sort_order`
- `is_enabled`

### 3) Entitlement rule
- `leave_entitlement_rules.id`
- `leave_policy_profile_id`
- `leave_type_code`
- `accrual_mode` (`anniversary|calendar|monthly|manual`)
- `tenure_months_from`
- `tenure_months_to`
- `granted_days`
- `max_days_cap`
- `carry_forward_mode` (`none|limited|custom`)
- `carry_forward_days`
- `effective_from`
- `effective_to`

### 4) Holiday source/day
- `holiday_calendar_sources.id`
- `country_code`
- `source_type` (`official_api|uploaded_calendar|manual`)
- `source_name`
- `source_ref`
- `is_enabled`
- `last_synced_at`

- `holiday_calendar_days.id`
- `country_code`
- `holiday_date`
- `holiday_name`
- `holiday_category` (`national|company_extra|merged|substitute`)
- `is_paid_day_off`
- `source_id`

### 5) Compliance/decision
- `leave_compliance_warnings.id`
- `warning_type`
- `severity` (`info|warning|critical`)
- `title`
- `message`
- `country_code`
- `related_rule_ref`
- `is_resolved`
- `resolved_at`
- `resolved_by`

- `leave_policy_decisions.id`
- `policy_profile_id`
- `decision_type`
- `decision_title`
- `decision_note`
- `approved_by`
- `approved_at`
- `attachment_ref`

---

## B. Frontend Ready Fields (Can Wire Now)

### Settings: policy profile
- `country_code`
- `policy_name`
- `effective_from`
- `effective_to`
- `leave_year_mode`
- `holiday_mode`
- `allow_cross_country_holiday_merge`
- `payroll_policy_mode`
- `compliance_warning_enabled`
- `notes`

### Settings: leave types
- `leave_type_code`
- `display_name`
- `is_paid`
- `affects_payroll`
- `requires_attachment`
- `requires_approval`
- `sort_order`
- `is_enabled`

### Settings: entitlement rules
- `leave_type_code`
- `accrual_mode`
- `tenure_months_from`
- `tenure_months_to`
- `granted_days`
- `max_days_cap`
- `carry_forward_mode`
- `carry_forward_days`

### Settings: holiday
- `country_code`
- `source_type`
- `source_name`
- `is_enabled`
- `last_synced_at`
- `holiday_date`
- `holiday_name`
- `holiday_category`
- `is_paid_day_off`

### Governance
- `warning_type`
- `severity`
- `title`
- `message`
- `country_code`
- `is_resolved`
- `decision_type`
- `decision_title`
- `approved_by`
- `approved_at`

---

## C. Fields That Will Affect `leave_requests`

Primary impact mapping (next integration step):
- `leave_types.leave_type_code` -> validate `leave_requests.leave_type`
- `leave_types.requires_approval` -> initial `leave_requests.approval_status` flow
- `leave_types.requires_attachment` -> whether attachment is required for submit
- `leave_types.affects_payroll` / `is_paid` -> default `leave_requests.affects_payroll`
- `leave_policy_profiles.effective_from/effective_to` -> which policy applies to request date range
- `leave_policy_profiles.holiday_mode` + `holiday_calendar_days` -> working-day vs holiday-day evaluation
- `leave_entitlement_rules` -> quota / accrual / carry-forward check reference

---

## D. Future Impact to Payroll / Attendance

### Payroll (future)
- `leave_types.is_paid`
- `leave_types.affects_payroll`
- `leave_policy_profiles.payroll_policy_mode`
- `leave_entitlement_rules.granted_days`, `max_days_cap`, `carry_forward_*`

### Attendance (future)
- `holiday_calendar_days.holiday_date`
- `holiday_calendar_days.is_paid_day_off`
- `holiday_calendar_days.holiday_category`
- `leave_policy_profiles.holiday_mode`
- `leave_policy_profiles.allow_cross_country_holiday_merge`

---

## E. Warning Semantics (Prompt Only, No Blocking)

`leave_compliance_warnings` is advisory in v1:
- Warning is recorded and shown in governance center.
- Leave submit/approve flow is **not blocked** by warning rows.
- `severity='critical'` still remains non-blocking in v1; escalation is via UI/system notice.
- Closure lifecycle:
  - unresolved: `is_resolved=false`, `resolved_at=null`
  - resolved: `is_resolved=true`, `resolved_at` set

---

## Holiday/Country Strategy (Documented Only)

### 1) Holiday source strategy
- `official_api`: national/public calendar sync source (future connector, no global auto-crawl in this round).
- `uploaded_calendar`: HR upload normalized calendar file.
- `manual`: direct admin entry for exceptional/non-standard holidays.
- Priority suggestion for resolve (future): `manual` > `uploaded_calendar` > `official_api`.

### 2) `country_code` strategy
- Use ISO 3166-1 alpha-2 uppercase (e.g., `TW`, `JP`, `KR`).
- Policy profile and holiday data are both country-keyed.
- For mixed workforce, use one active policy profile per `country_code` + effective date window.

### 3) Manual override strategy
- Override is represented by `holiday_calendar_sources.source_type='manual'` + `holiday_calendar_days`.
- Recommended audit trail:
  - create warning row for risky override (`warning_type='holiday_override'`)
  - create decision row in `leave_policy_decisions` with approver metadata
- Override does not delete source data; it supersedes at resolve layer.

### 4) Merged holiday strategy
- Cross-country merge is governed by:
  - `leave_policy_profiles.allow_cross_country_holiday_merge`
  - `holiday_calendar_days.holiday_category='merged'`
- MVP rule (future resolver):
  - when merge enabled, merged day can be treated as valid day-off candidate
  - when disabled, resolver must ignore `merged` rows outside policy country
