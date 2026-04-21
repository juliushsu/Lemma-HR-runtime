# Payroll Calculation Phase 1 Governance v1

## Purpose

Define the canonical payroll calculation skeleton for Lemma HR+ Phase 1.

This document is intentionally preview-first. It is meant to stop the team from creating:

- one route family for settings
- another unrelated route family for preview
- a third incompatible path for future payroll run or payslip issuance

Phase 1 establishes one governance model that later payroll preview, payroll run, and payslip families can extend without route or policy drift.

## Canonical Runtime

Canonical frontend-facing runtime for payroll calculation Phase 1 must be:

- `Railway`

Reason:

1. payroll scope must be resolved from JWT + selected context
2. payroll settings are company-scoped governance, not frontend-owned state
3. preview calculation needs multi-source aggregation
4. calculation logic and warning policy should not be exposed directly to frontend clients
5. future payroll run and payslip issuance should remain in the same application-owned contract family

## Canonical Family

Phase 1 canonical family namespace is:

- `/api/payroll/*`

Phase 1 canonical families are:

- `GET /api/payroll/settings`
- `PATCH /api/payroll/settings`
- `GET /api/payroll/preview`
- `GET /api/payroll/preview/:employee_id`
- `GET /api/payroll/preview/:employee_id/breakdown`

Reserved but deferred:

- `GET /api/payroll/components`

Future families must stay separate:

- payroll run / closing:
  - `/api/payroll/runs/*`
- payslip issuance:
  - `/api/payroll/payslips/*`

Preview and run must not be mixed into one mutable route family.

## Preview vs Run Decision

Phase 1 decision:

- payroll preview is in scope
- payroll run / payroll closing / locking are deferred
- payslip generation and issuance are deferred

Canonical rule:

- `/api/payroll/preview*` is read-only and non-closing
- `/api/payroll/runs*` is a future execution family and must not be backfilled into preview routes later

This separation avoids the common failure mode where a "preview" route quietly starts owning persistent payroll execution behavior.

## Scope Model

Phase 1 scope source must be:

- selected context + JWT only

Not allowed as truth:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`

Company scope is the canonical Phase 1 policy scope.

Location / branch override exists only as a governance boundary in Phase 1 and is not yet part of the writable surface.

## Role Model

Phase 1 writable settings roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Phase 1 preview readers may later broaden, but initial governance assumes HR / admin readers only:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Not in Phase 1:

- self payroll preview for employees
- manager payroll preview

## Company Default vs Employee Override Boundary

Phase 1 formal boundary:

- company-level payroll policy: `in scope`
- employee-level compensation override: `missing`
- location / branch payroll override: `deferred`

Interpretation:

1. company-level settings define the canonical payroll policy baseline
2. employee-level compensation settings are required for a fully accurate preview, but current substrate is not yet established
3. until employee-level compensation settings exist, preview must clearly mark missing inputs and warnings rather than invent implicit defaults
4. location / branch override must not be silently embedded into Phase 1 settings

## Phase 1 Policy Model

Phase 1 payroll policy should govern four layers:

1. payroll company settings
2. payroll component families
3. payroll-facing leave compensation policy
4. preview output model

## Earnings Component Families

Phase 1 payroll calculation must recognize at least these earnings families:

| Family | Default classification | Notes |
| --- | --- | --- |
| `base_salary` | `recurring_fixed` | canonical base compensation anchor |
| `attendance_bonus` | `recurring_variable` | conditional recurring earning; must honor protected leave rules |
| `performance_bonus` | `recurring_variable` | recurring but result-driven |
| `festival_bonus` | `one_off` | holiday / festival bonus, non-monthly by default |
| `year_end_bonus` | `one_off` | annual or closing-cycle bonus |
| `meal_allowance` | `recurring_fixed` | fixed by default, may later support employee override |
| `transport_allowance` | `recurring_fixed` | fixed by default |
| `other_allowance` | `recurring_variable` | catch-all family; must remain explicitly labeled |

Canonical recurrence values:

- `recurring_fixed`
- `recurring_variable`
- `one_off`

## Deduction Component Families

Phase 1 payroll calculation must recognize at least these deduction families:

- `late_penalty`
- `absence_deduction`
- `leave_deduction`
- `labor_insurance_employee`
- `health_insurance_employee`
- `other_deduction`

Interpretation:

- attendance-related deductions come from attendance / leave inputs and policy application
- insurance deductions are payroll-facing deduction families even when a separate insurance engine is deferred
- `other_deduction` must never be used as an unlabeled black box in preview output; each applied item must still carry explanation metadata

## Payroll-Facing Leave Policy Layer

Payroll calculation must not collapse leave into only `paid` or `unpaid`.

The canonical payroll-facing leave policy model has three layers.

### 1. Entitlement Layer

Purpose:

- represent whether the leave is statutory, company-policy, or otherwise governed

Required model fields:

- `jurisdiction_code`
- `statutory_leave_type`
- `company_policy_leave_type`

### 2. Compensation Layer

Purpose:

- represent how the leave affects payroll-visible income

Required model fields:

- `compensation_mode`
- `compensation_ratio`

Allowed compensation modes:

- `paid_full`
- `paid_partial`
- `unpaid`

Examples:

- `paid_full` + `compensation_ratio = 1.0`
- `paid_partial` + `compensation_ratio = 0.5`
- `unpaid` + `compensation_ratio = 0.0`

### 3. Funding Source Layer

Purpose:

- distinguish who bears the payroll-visible income and who bears employer payroll cost

Required model fields:

- `funding_source`
- `employer_cost_included`
- `employee_income_included`

Allowed funding values:

- `employer_paid`
- `government_paid`
- `social_insurance_paid`
- `mixed`

This distinction is mandatory for Phase 1 governance even if some preview fields remain `null` during early implementation.

## Taiwan-First but Globally Extensible

Phase 1 canonical jurisdiction is:

- `TW`

But the model must remain globally extensible.

Required extensibility fields in the canonical policy model:

- `jurisdiction_code`
- `statutory_leave_type`
- `company_policy_leave_type`
- `compensation_ratio`
- `funding_source`
- `employer_cost_included`
- `employee_income_included`

These should not be deferred out of the model, even if some are only partially exposed in the first route implementation.

## Leave Types That Must Be Explicitly Governed

Phase 1 governance must explicitly address at least these leave-facing payroll cases:

| Leave type | Entitlement layer | Compensation layer | Funding source layer | Attendance bonus protection | Phase 1 note |
| --- | --- | --- | --- | --- | --- |
| `annual_leave` | statutory in Taiwan payroll context | `paid_full`, `1.0` | `employer_paid` | `true` | unused leave payout belongs to later payroll run / closing |
| `personal_leave` | statutory leave rule layer | `unpaid`, `0.0` | `employer_paid` | `false` by default | may produce leave deduction |
| `sick_leave` | statutory leave rule layer | `paid_partial`, `0.5` by default for statutory ordinary sick-leave treatment | `mixed` | proportional protection only | do not treat as simple unpaid absence |
| `family_care_leave` | statutory equality-law leave layer | follow personal-leave compensation treatment unless law or company policy is better | `employer_paid` | `true` | payroll must not reduce attendance bonus solely because it is family care leave |
| `marriage_leave` | statutory leave rule layer | `paid_full`, `1.0` | `employer_paid` | `true` | protected full-pay leave |
| `bereavement_leave` | statutory leave rule layer | `paid_full`, `1.0` | `employer_paid` | `true` | protected full-pay leave |
| `maternity_leave` | statutory equality-law leave layer | `paid_full` for employee-income view | `mixed` | `true` | payroll must keep employer cost and non-employer-funded amount distinguishable |
| `parental_leave` / `childcare_leave` | statutory equality-law leave layer | employer payroll may be `unpaid`, but employee visible income may still exist | `mixed` | `true` | do not treat government / insurance benefit as employer payroll cost |
| `public_holiday` / `national_holiday` | statutory holiday layer | `paid_full`, `1.0` | `employer_paid` | `true` | not a deduction source |
| `natural_disaster_leave` / `typhoon_leave` | company-configured policy on top of statutory attendance-protection guidance | configurable | company-configured | `true` | never auto-map to unexcused absence |
| `absence` / `unexcused_absence` | not a leave entitlement | `unpaid`, `0.0` | `employer_paid` | `false` | distinct from leave governance |

## Natural Disaster Leave Governance

Natural disaster leave must not be modeled as ordinary personal leave or ordinary absence.

Phase 1 payroll policy must allow company-level configuration:

- `unpaid`
- `half_paid`
- `paid_full`

Recommended canonical object:

- `natural_disaster_leave_policy`
  - `compensation_mode`
  - `compensation_ratio`
  - `funding_source`
  - `excluded_from_attendance_bonus_deduction`
  - `warning_note`

Mandatory governance notes for Taiwan Phase 1:

- do not treat natural-disaster non-attendance as unexcused absence
- do not use natural-disaster non-attendance as the sole reason to reduce attendance bonus
- do not replace leave governance with disciplinary handling

This rule is informed by Taiwan Ministry of Labor disaster-attendance guidance and should be preserved even when a company chooses `unpaid`.

## Payroll Inputs

Phase 1 payroll preview should consume these canonical inputs:

| Input source | Phase 1 status | Governance note |
| --- | --- | --- |
| approved leave data | `available` | use approved leave only |
| attendance summary / attendance events | `partial` | append-only event source exists; summary read model may still need convergence |
| attendance corrections | `available` for approved corrections only | rejected / pending corrections must not affect preview |
| salary base settings | `missing` | company-level payroll settings family defines policy, not employee salary base amounts |
| employee compensation settings | `missing` | must be treated as explicit missing substrate |
| manual payroll adjustments | `deferred` | not in Phase 1 preview calculation |

Canonical rule:

- preview must read approved / finalized operational inputs only
- preview must not invent employee compensation defaults when the substrate is missing
- missing inputs must surface in `warnings[]`

## Payroll Outputs

Minimum canonical preview outputs:

- `gross_pay`
- `total_earnings`
- `total_deductions`
- `net_pay`
- `breakdown_items[]`
- `policy_applied[]`
- `warnings[]`

Extended output model that should be defined now, even if some fields are initially `null`:

- `gross_pay_employer_basis`
- `leave_compensation_employer_paid`
- `leave_compensation_non_employer_paid`
- `employee_total_visible_income`
- `net_pay_employer_payable`

Phase 1 governance decision:

- these extended fields belong to the canonical preview model
- first route implementation may return `null` when upstream funding-source inputs are not yet fully available
- they must not be omitted from governance simply because employee compensation substrate is incomplete

## Payroll Settings Family

Phase 1 payroll settings should govern:

- `jurisdiction_code`
- `currency_code`
- payroll preview mode
- component family catalog and enablement policy
- leave compensation rules
- natural disaster leave policy
- attendance-bonus protection policy
- override model metadata

Recommended response sections:

- `jurisdiction`
- `payroll_settings`
- `earnings_component_families`
- `deduction_component_families`
- `leave_compensation_rules`
- `natural_disaster_leave_policy`
- `override_model`

## Preview Family

Phase 1 preview family should expose:

- company-scoped payroll preview list
- employee-scoped preview summary
- employee-scoped breakdown

Recommended behavior:

1. resolve company scope from selected context
2. load payroll settings policy
3. load approved leave and approved attendance correction inputs
4. compute preview summary
5. expose warnings for missing compensation substrate or deferred components

## Components Family Boundary

`GET /api/payroll/components` is reserved for a future shared explanation catalog.

Phase 1 decision:

- route name is reserved now
- first implementation may defer this route
- component explanation must still be available through `breakdown_items[]` and `policy_applied[]`

## In Scope

Phase 1 is in scope for:

- payroll settings governance
- payroll-facing leave compensation governance
- payroll preview read model
- employee-level preview breakdown model
- Taiwan-first policy defaults with globally extensible fields
- preview vs run family separation

## Deferred

Deferred beyond Phase 1:

- payroll closing / payroll run execution
- payslip generation / issuance
- tax withholding output
- bank transfer export
- accounting integration
- roster-aware payroll differentials
- overtime engine
- holiday premium calculation
- multi-country payroll compliance
- manual payroll adjustments
- employee self payroll portal
- branch / location payroll override write

## Recommended First Implementation Target

If implementation starts next round, the best first route is:

- `GET /api/payroll/settings`

Reason:

1. it anchors the company-level payroll policy truth source first
2. preview routes should not be implemented before policy shape exists
3. it creates a stable contract for later preview computation and warnings

## Official Taiwan Context Notes

This governance document is Taiwan-first and was shaped using official Taiwan labor-law sources, including:

- Labor Standards Act special-leave provisions
- Rules of Leave-Taking of Workers
- Gender Equality in Employment Act
- Ministry of Labor disaster-attendance guidance
- BLI / MOL material on parental-leave subsidy handling

Where payroll cost treatment is not identical to employee visible income, this document intentionally models:

- employer cost
- non-employer-funded income
- employee visible income

as separate concepts.
