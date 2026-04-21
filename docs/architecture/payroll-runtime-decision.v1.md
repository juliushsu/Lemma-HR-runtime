# Payroll Runtime Decision v1

## Purpose

Define the canonical runtime ownership for payroll calculation Phase 1.

This decision covers:

- payroll settings family
- payroll preview family
- future separation between preview and payroll run

## Decision

Canonical frontend-facing runtime for payroll calculation Phase 1 is:

- `Railway`

## Why Railway

Payroll calculation depends on:

1. authenticated JWT actor resolution
2. selected-context company scope resolution
3. HR / admin role enforcement
4. multi-source aggregation across leave, attendance, corrections, and payroll policy
5. controlled preview response shaping with warnings and policy metadata
6. future separation between preview and payroll run execution

These are application orchestration concerns and should remain in Railway.

## Why Not Supabase Edge

Payroll calculation should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime
- payroll routes need app-level HR scope and role decisions
- preview computation will likely aggregate more than one source family
- future payroll run safety should not fragment across edge functions and app routes

Supabase Edge may still appear later as a narrow internal compute substrate, but it should not own the public contract.

## Why Not DB / RPC As Frontend Runtime

`DB / RPC / direct client` may remain an internal calculation substrate later, but should not own the frontend contract.

Reason:

- contract ownership should remain in one app route family
- selected-context interpretation must not split between frontend, DB policy, and app route
- warning shaping, preview-state labeling, and missing-input interpretation are app concerns

## Preview vs Run Decision

Phase 1 formal decision:

- preview and run must be separate families

Phase 1 preview family:

- `/api/payroll/preview*`

Deferred run family:

- `/api/payroll/runs*`

Deferred payslip family:

- `/api/payroll/payslips*`

Reason:

- preview is read-only and reversible
- payroll run is stateful and lock-sensitive
- payslip issuance is a document / distribution concern

These must not be collapsed into one multi-purpose route family.

## Scope Decision

Phase 1 scope source is:

- selected context + JWT only

Not allowed:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `environment_type`

The selected company context is the canonical target company for:

- payroll settings
- payroll preview

## Company Policy vs Override Decision

Phase 1 boundary:

- company-level payroll policy: `in scope`
- employee-level override: `missing`
- location / branch override: `deferred`

Interpretation:

- company-level defaults belong to `/api/payroll/settings`
- employee-level compensation settings need a future canonical family and should not be invented inside preview routes
- location / branch payroll override should not enter Phase 1 unless explicitly added as a later decision

## Response Ownership Decision

Payroll preview responses must remain application-owned because they need:

- stable calculation summary fields
- breakdown explanation fields
- policy-applied metadata
- missing-input warnings

This is not just raw table access.

## Temporary Compatibility Decision

There is no approved MVP payroll route family today.

Phase 1 should therefore avoid creating:

- one route family for settings under `/api/settings/*`
- another preview family under `/api/payroll/*`

Canonical payroll policy and payroll preview should both live under `/api/payroll/*` from the start.

## Recommended Implementation Order

If implementation starts next round:

1. `GET /api/payroll/settings`
2. `PATCH /api/payroll/settings`
3. `GET /api/payroll/preview/:employee_id`
4. `GET /api/payroll/preview/:employee_id/breakdown`
5. `GET /api/payroll/preview`

This order keeps policy source ahead of preview math.

## Non-goals

This runtime decision does not include:

- payroll closing
- payslip issuance
- tax output
- bank export
- accounting integration
- overtime engine
- holiday premium engine
- multi-country payroll execution
