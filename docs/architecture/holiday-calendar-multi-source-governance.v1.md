# Holiday Calendar Multi-Source Governance v1

## Purpose

Define the canonical governance model for multi-source holiday calendar management in Lemma HR+.

This layer is intended to become the shared baseline for:

- leave-policy interpretation
- attendance-policy interpretation
- payroll interpretation
- legal governance checks

This document defines governance and data ownership only.

This document does not define:

- live routes
- DB migration
- UI
- external source sync implementation

## Problem Statement

Lemma HR+ must support more than one holiday source at the same time.

Real company scenarios include:

- Taiwan-registered companies that still observe HQ or parent-country holidays
- factories that selectively grant cultural holidays to foreign-worker groups
- regional group governance where statutory local holidays remain primary, while group calendars remain secondary and discretionary

The system therefore cannot model holiday calendars as:

- one country = one calendar = one truth

Instead, it must model:

- one primary legal baseline
- zero to many secondary calendars
- scoped adoption rules
- explicit conflict governance
- downstream consumption across four business domains

## Canonical Model

### Core Design

The canonical model should separate:

1. holiday source definition
2. company adoption settings
3. scope targeting
4. resolved preview output
5. governance / legal interpretation

### Source Layers

#### Primary calendar

Primary calendar means:

- the company registration jurisdiction statutory holiday baseline

Phase 1 decision:

- exactly one primary calendar per company scope
- primary calendar is mandatory
- primary calendar is the legal baseline for leave / attendance / payroll / legal governance

Examples:

- Taiwan company -> Taiwan statutory calendar
- Japan company -> Japan statutory calendar

#### Secondary calendars

Secondary calendars mean discretionary or imported calendars that may influence company-observed holidays for all or part of the workforce.

Supported secondary origin types:

- parent company country
- regional HQ country
- expatriate origin country
- foreign-worker group country
- business-unit specific country calendar
- culturally selected holiday set

Phase 1 decision:

- multiple secondary calendars are supported
- each secondary calendar may be adopted independently
- secondary calendars never automatically override the primary legal baseline

## Canonical Data Model

### Company holiday calendar settings

Recommended canonical company settings object:

- `primary_calendar`
- `secondary_calendars[]`
- `policy_mode`
- `scope_support`
- `conflict_rules`
- `preview_defaults`
- `downstream_consumption_flags`

### `primary_calendar`

Required fields:

- `jurisdiction_code`
- `calendar_code`
- `source_type`
- `legal_basis_strength`

Recommended values:

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
- `selected_holiday_codes[]`
- `scope_type`
- `scope_refs[]`
- `governance_strength`
- `priority_rank`
- `enabled`

Phase 1 decision:

- many secondary calendars are allowed
- partial adoption is allowed
- scope-limited adoption is allowed

### `adoption_mode`

Recommended Phase 1 values:

- `disabled`
- `selected_holidays_only`
- `full_calendar_reference`

Phase 1 runtime rule:

- `selected_holidays_only` is supported
- `full_calendar_reference` may exist in settings as a valid value
- but preview / downstream interpretation should still resolve through policy mode and conflict rules

### `selection_mode`

Recommended values:

- `all_source_holidays`
- `selected_codes_only`

Phase 1 decision:

- `selected_codes_only` is the safer default for secondary calendars

### `scope_type`

Supported canonical values:

- `company`
- `location`
- `department`
- `employee_group`
- `employee`

Phase 1 support decision:

- `company`
- `location`
- `employee_group`

Deferred:

- `department`
- `employee`

Reason:

- company / location / employee-group are the lowest-complexity shared governance surfaces across leave, attendance, payroll, and legal
- department and employee-specific write governance would introduce high operational ambiguity too early

## Scope Governance

### Company-wide

Meaning:

- applies to the entire selected company scope

Phase 1:

- supported

### Location / branch

Meaning:

- applies only to one or more branch / location scopes

Phase 1:

- supported as a scoped adoption target

### Department

Meaning:

- applies to a department-defined workforce subset

Phase 1:

- deferred

Reason:

- department trees and cross-location department membership create additional ambiguity in a first shared calendar layer

### Employee group

Meaning:

- applies to an explicitly managed eligibility group such as expatriates, foreign-worker cohorts, or designated operations groups

Phase 1:

- supported

Recommended use cases:

- Thailand Songkran group holiday
- Indonesia / Vietnam / Philippines cultural holiday groups
- HQ-synced expatriate populations

### Employee-specific

Meaning:

- applies to one named employee only

Phase 1:

- deferred

Reason:

- too easy to turn the holiday layer into ad hoc exception storage instead of governed policy

## Conflict Governance

### Principle

Primary calendar remains the legal baseline.

Secondary calendars are discretionary adoption inputs, not autonomous overrides.

### Canonical policy modes

#### `primary_only`

Interpretation:

- only the primary calendar produces observed holidays

Phase 1:

- supported

#### `primary_plus_selected_secondary`

Interpretation:

- primary calendar remains baseline
- only selected secondary holidays explicitly adopted by the company are added

Phase 1:

- supported

This should be the recommended Phase 1 discretionary model.

#### `union_observed_days`

Interpretation:

- union all observed days from primary and enabled secondary calendars inside the applicable scope

Phase 1:

- deferred

Reason:

- too easy to create accidental excess leave exposure without explicit per-holiday governance

#### `scope_based_override`

Interpretation:

- a scoped secondary rule may replace the effective observed-day outcome for the covered scope

Phase 1:

- partially supported in constrained form only

Allowed Phase 1 interpretation:

- secondary calendars may add scoped holidays
- they may not erase statutory primary holidays
- they may not silently convert a primary statutory holiday into a working day

Deferred interpretation:

- full override engine with rich precedence chains

### Conflict cases

#### Same day, different labels

Canonical rule:

- one observed day may carry multiple source labels
- the effective day status should not duplicate leave entitlement
- preview output should retain both labels for explanation

Phase 1:

- supported as preview metadata

#### Primary workday, secondary holiday

Canonical rule:

- only becomes an observed non-working day if company governance explicitly adopts that secondary holiday for the applicable scope

Default if not adopted:

- remains working day

#### Primary holiday, secondary workday

Canonical rule:

- primary statutory holiday remains holiday
- secondary working-day status cannot cancel it

Phase 1:

- primary wins

## Holiday Classification

### Canonical holiday type

Holiday records should classify at least:

- `statutory_public_holiday`
- `company_observed_holiday`
- `imported_secondary_holiday`
- `selected_cultural_welfare_holiday`

### Governance class

Each effective holiday outcome should also classify:

- `statutory_minimum`
- `company_discretionary_benefit`
- `group_sync_observed_day`
- `scope_specific_discretionary_day`

Interpretation:

- statutory minimum -> legal baseline, higher legal sensitivity
- company discretionary benefit -> internal company choice
- group sync observed day -> parent / HQ alignment choice
- scope specific discretionary day -> explicit group or location benefit

## Consumption Map

### Leave-policy consumption

Holiday calendar layer should provide:

- statutory holiday baseline for leave displays and company rule explanations
- company-observed holiday resolution
- scoped holiday eligibility input for group-specific non-working days

Leave-policy must consume:

- effective observed-day status
- holiday governance class
- applicable scope metadata

Leave-policy should not own:

- external calendar adoption logic
- cross-calendar conflict policy

### Attendance-policy consumption

Holiday calendar layer should provide:

- whether the date is an observed non-working day for the employee scope
- whether the observed day came from primary or secondary governance
- whether the day is scope-wide or scope-limited

Attendance-policy must consume:

- exempt-from-attendance baseline
- scope-based schedule exception signal
- explanation metadata for correction / exception review

Attendance-policy should not own:

- secondary calendar selection rules
- group-holiday governance authoring

### Payroll consumption

Holiday calendar layer should provide baseline classification only, not full payroll posting.

Payroll should consume:

- effective observed day classification
- statutory vs discretionary class
- whether the day should default to paid holiday, unpaid discretionary day, or special review-required day

Phase 1 payroll interpretation examples:

- statutory public holiday -> default legal holiday basis
- company-observed holiday -> company-paid or policy-defined discretionary paid day basis
- selected cultural / welfare holiday -> discretionary company benefit basis
- group-sync holiday -> company-observed discretionary basis

This layer should not perform:

- payroll run execution
- automatic posting
- overtime premium calculation finalization

It should provide the baseline classification payroll needs to decide those outcomes.

### Legal governance checks consumption

Legal governance should consume:

- primary statutory baseline
- company-adopted observed calendar state
- whether a secondary holiday is statutory or discretionary
- whether a company is below statutory minimum or merely choosing among discretionary options

Canonical legal rule:

- failure to honor primary statutory minimum may produce governance risk
- adopting or declining a secondary holiday is generally company discretion unless another legal obligation exists
- AI may recommend discretionary adoption, but must not auto-overwrite company calendar settings

## Phase 1 Scope

Phase 1 includes:

- one primary calendar per company
- multiple secondary calendars
- selected-secondary adoption model
- secondary partial-holiday selection
- scoped application for company / location / employee_group
- preview/read model for effective holiday outcomes
- conflict governance with primary-baseline protection
- shared consumption boundary for leave / attendance / payroll / legal governance

## Deferred

Deferred from Phase 1:

- government API auto-sync
- global official-source crawler ingestion
- automatic AI holiday merge
- department-level write governance
- employee-level calendar write
- real-time override engine
- automatic attendance rescheduling
- automatic payroll posting
- autonomous conflict resolution without human settings governance
- full union-of-all-calendars policy mode

## Final Governance Position

The holiday calendar layer is not a generic holiday dataset.

It is a governed shared policy layer with:

- one legal baseline
- many optional secondary inputs
- explicit scope targeting
- explicit conflict rules
- explainable downstream consumption

That boundary is the key Phase 1 decision.
