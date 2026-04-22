# Holiday Calendar Runtime Decision v1

## Purpose

Define the canonical runtime ownership for holiday calendar multi-source governance.

This decision covers:

- holiday calendar settings family
- holiday calendar preview family
- downstream shared-consumption boundary

## Decision

Canonical frontend-facing runtime for holiday calendar governance is:

- `Railway`

## Why Railway

Holiday calendar governance depends on:

1. authenticated JWT actor resolution
2. selected-context company scope resolution
3. organization settings write-role enforcement
4. shared interpretation across leave, attendance, payroll, and legal governance
5. scoped adoption logic for company / location / employee-group targeting
6. conflict resolution explanation for primary vs secondary calendars
7. stable preview response shaping for downstream consumers

These are application orchestration concerns and should stay in Railway.

## Why Not Supabase Edge

Holiday calendar governance should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime
- shared cross-module semantics should not fragment into edge-only contracts
- role / scope / preview explanation logic belongs in one application-owned family

Edge may appear later as a narrow helper substrate for source ingestion or sync, but it should not own the public contract.

## Why Not DB / RPC As Frontend Runtime

`DB / RPC / direct client` may later become an internal substrate, but it should not own the frontend contract.

Reason:

- holiday calendar is not only raw date storage
- primary / secondary conflict governance is app-level policy interpretation
- selected-context and organization settings ownership should not split across frontend and DB policy
- downstream preview hints are app-shaped, not raw table output

## Shared Layer Decision

Holiday calendar is a shared foundational layer, not a leave-only or attendance-only feature.

Formal ownership rule:

- write governance belongs to the dedicated holiday-calendar settings family
- consuming modules read resolved outputs and classification metadata
- consuming modules do not own calendar-source selection semantics

## Scope Decision

Phase 1 scope source is:

- selected context + JWT only

Not allowed:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`

Phase 1 supported application scopes inside the family:

- `company`
- `location`
- `employee_group`

Deferred:

- `department`
- `employee`

## Contract Boundary Decision

The canonical public family should be:

- `/api/settings/holiday-calendar`
- `/api/settings/holiday-calendar/preview`

Reason:

- this is a settings-governed shared policy layer
- preview belongs next to settings because it resolves effective outcomes from configured governance
- it should not be split across leave, attendance, payroll, or legal route families

## Downstream Consumption Decision

Downstream families consume holiday-calendar outputs as follows:

- leave-policy consumes effective observed days
- attendance-policy consumes non-working-day baseline
- payroll consumes holiday classification baseline
- legal governance consumes statutory-vs-discretionary boundary

Those families may add their own domain rules, but must not reinterpret:

- primary calendar authority
- secondary calendar adoption semantics
- scoped holiday eligibility source

## Phase 1 Decision

Phase 1 includes:

- primary calendar settings
- multiple secondary calendars
- selected-secondary adoption
- scoped adoption for company / location / employee_group
- preview/read family
- shared downstream boundary definition

Phase 1 does not include:

- government API sync
- crawler ingestion
- employee-specific write
- real-time override engine
- automatic attendance rescheduling
- automatic payroll posting
- AI auto-merge of calendars

## Recommended Implementation Order

If implementation starts next round:

1. `GET /api/settings/holiday-calendar`
2. `PATCH /api/settings/holiday-calendar`
3. `GET /api/settings/holiday-calendar/preview`

Reason:

- settings truth must exist before preview
- preview is the first shared consumer-facing verification layer
- this order reduces the chance that leave / attendance / payroll invent parallel interpretations
