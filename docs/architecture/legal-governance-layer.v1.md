# Legal Governance Layer v1

## Purpose

Define the canonical architecture for Lemma HR+'s AI-assisted legal governance layer.

This layer is intended to make legal governance:

- continuously comparable
- explainable
- human-reviewable
- non-destructive by default

It is not intended to let AI silently overwrite customer policy.

## Product Principle

Lemma's legal governance layer is a living governance system, not an autonomous legal actor.

Its job is to:

- observe legal changes
- compare those changes with company policy
- generate risk-aware suggestions
- preserve human adoption authority

It must not:

- auto-overwrite customer policy
- auto-change payroll settings
- auto-change leave policy
- auto-publish a final legal conclusion
- replace a human decision-maker in adoption workflows

## AI Role

AI is allowed to do only these tasks:

- legal change detection
- compliance risk flagging
- suggested rule-value generation
- statutory-text vs company-rule comparison summary
- high-risk reminder generation

AI is not allowed to do these tasks automatically:

- direct policy overwrite
- direct payroll configuration update
- direct leave-policy update
- direct attendance-policy update
- formal legal signoff
- final adoption decision on behalf of a human administrator

## Three-Layer Governance Model

The legal governance layer must be modeled as three distinct layers.

### 1. Legal Knowledge Layer

This layer stores or derives:

- applicable jurisdiction
- legal source reference
- article / rule summary
- effective date
- version delta
- statutory minimum
- exception conditions
- funding source
- compensation ratio
- employer obligation

This is the "what the law or official guidance says" layer.

### 2. Governance Comparison Layer

This layer compares:

- statutory minimum
- current company policy
- AI suggested value
- deviation degree
- risk severity

This is the "what changed and how far the company is from it" layer.

### 3. Decision / Adoption Layer

This layer records a human choice:

- adopt statutory minimum
- adopt better-than-minimum company policy
- keep current policy and accept warning
- defer adoption

This is the "what the company decided to do" layer.

## Ownership Model

The legal governance layer has two ownership zones.

### System-Level Managed

These must be platform-owned only:

- legal model selection
- fallback model selection
- provider / key binding
- auto update schedule
- global legal scanning policy
- jurisdiction refresh behavior
- risk-threshold base defaults
- base legal knowledge refresh

Customers must not directly control these system settings.

### Customer-Level Accessible

Customers may interact with:

- legal update results relevant to their company
- governance comparison results for their own policies and documents
- document / policy analysis results
- adoption actions:
  - adopt suggestion
  - keep current
  - acknowledge warning

Customers may use AI-assisted governance, but they may not control the platform's underlying legal model topology.

## Canonical Families

Phase 1 canonical families are:

### A. System Legal Governance Settings Family

- `GET /api/system/legal-governance/settings`
- `PATCH /api/system/legal-governance/settings`

This family is:

- system-level
- platform-owned
- not customer-owned

### B. Legal Updates Family

- `GET /api/legal/updates`
- `GET /api/legal/updates/:id`

### C. Governance Checks Family

- `GET /api/legal/governance-checks`
- `GET /api/legal/governance-checks/:id`

### D. Policy Adoption / Override Family

Reserved Phase 1 action family:

- `POST /api/legal/governance-checks/:id/adopt-suggestion`
- `POST /api/legal/governance-checks/:id/keep-current`
- `POST /api/legal/governance-checks/:id/acknowledge-warning`

### E. Document / Policy Analysis Family

Reserved analysis family:

- `POST /api/legal/analyze/document`
- `POST /api/legal/analyze/policy`

This family is customer-facing in outcome, but still relies on platform-managed model configuration.

## Applicability Model

Every legal knowledge or governance-check object should support at least:

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

## Governance Check Model

Each governance check should contain at least:

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

## Legal Update Model

Each legal update object should express at least:

- which rule changed
- which jurisdiction changed
- whether the effective date has arrived
- whether the change is mandatory or advisory
- whether the change affects:
  - leave
  - payroll
  - attendance
  - contract
- whether the change appears to affect the company's current settings

This is the canonical "change-event" layer, distinct from governance checks.

## Rule Strength Model

The legal governance layer must formally distinguish:

- `mandatory_minimum`
- `recommended_best_practice`
- `company_discretion`

Interpretation:

- `mandatory_minimum`
  - law or official guidance establishes a minimum that cannot be undercut
- `recommended_best_practice`
  - not always legally mandatory, but governance should surface it as a recommended control
- `company_discretion`
  - company retains policy design discretion

This field is critical because not every AI suggestion should be treated as legally binding.

## Company Decision / Risk Acknowledgement Model

The system must support cases where the company knowingly does not adopt the AI suggestion.

Required fields:

- `company_decision_status`
- `source_ref`
- `updated_at`

Interpretation:

- `pending_review`
  - governance comparison exists, but the company has not yet recorded a decision
- `adopted`
  - company chose the suggested or improved direction
- `kept_current`
  - company intentionally keeps its current rule despite the comparison result
- `acknowledged_risk`
  - company explicitly accepts the remaining risk without adopting the suggestion

This preserves institutional memory and avoids the false appearance that risk disappeared merely because the company declined adoption.

## Example Domain: Leave / Holiday / Payroll-Facing Leave Compensation

Leave governance is a primary example domain for this layer.

The legal governance layer should support comparison among:

- statutory minimum
- company current rule
- AI suggested rule

Example leave domains that must be representable:

- national holidays
- annual leave
- sick leave
- personal leave
- marriage leave
- bereavement leave
- maternity leave
- parental / childcare leave
- natural disaster leave

### Taiwan-Facing Governance Notes

For Taiwan-facing governance, the system should preserve official legal structure rather than flatten everything into generic "paid/unpaid" labels.

Examples from official Taiwan sources that matter to this model include:

- annual leave under Labor Standards Act Article 38
- sick-leave compensation under Rules of Leave-Taking of Workers
- maternity / parental leave structure under the Act of Gender Equality in Employment
- natural-disaster attendance and wage guidance under Ministry of Labor disaster-attendance guidance

This means the legal governance layer must be able to distinguish:

- statutory entitlement
- compensation treatment
- funding source
- company bonus-protection rules

## Natural Disaster Leave Governance

Natural disaster leave is a special governance example.

The legal layer should allow a company policy to choose:

- unpaid
- half-paid
- paid-full

But the governance layer must still preserve warnings such as:

- not automatically equivalent to unexcused absence
- should not be used as the sole reason to reduce attendance bonus
- should not be replaced by disciplinary handling

This is a legal-governance comparison concern, even if payroll handling is decided in another family.

## High-Risk Work / Insurance Recommendation Governance

This domain belongs in the legal governance architecture, but is deferred as an implementation family.

The governance model should eventually support:

- high-risk occupation identification
- statutory responsibility vs company self-protection gap
- AI suggestion for extra coverage or reserve protection
- governance warning when the company declines better protection

Potential future recommendations may include:

- supplemental insurance
- pooled reserve concept
- governance-only self-protection recommendations

Phase 1 decision:

- include it in governance architecture
- do not implement pricing, underwriting, or insurer API integration yet

## Canonical Analysis Targets

The document / policy analysis layer should be designed to support at least:

- labor consulting agreements
- employment contracts
- fixed-term / contract employment agreements
- leave rules
- internal HR policies
- attendance policies
- payroll policies

Phase 1 may defer route implementation, but the governance layer should still reserve these analysis targets.

## Runtime Boundary

This layer is not a pure document store and not a raw AI-agent surface.

It requires:

- actor resolution
- selected context resolution
- role enforcement
- orchestration between legal knowledge and company policy objects
- stable auditable adoption actions

Therefore the public contract should remain application-owned, not frontend-owned.

## Phase 1 In Scope

Phase 1 is in scope for:

- legal governance settings model
- legal update model
- governance comparison model
- policy / contract analysis family skeleton
- policy adoption / acknowledgement lifecycle skeleton
- system-level vs customer-level ownership boundary

## Deferred

Deferred beyond Phase 1:

- full autonomous legal update execution
- direct automatic policy overwrite
- insurance pricing or insurer integration
- complete country-by-country employment law engine
- full document clause generation
- customer-controlled model switching
- real-time uncontrolled web crawling
- formal legal opinion issuance
- automatic customer policy mutation

## Official Source Note

This governance design is Taiwan-first in example domains and was informed by official Taiwan labor-law sources and related public guidance, including:

- Ministry of Labor law source system
- Ministry of Labor administrative guidance
- BLI subsidy guidance where parental-leave income and employer cost differ

These sources matter as governance anchors, but AI outputs remain advisory until a human adoption action occurs.
