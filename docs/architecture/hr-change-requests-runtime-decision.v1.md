# HR Change Requests Runtime Decision v1

## Purpose

Define the canonical runtime for the HR review side of employee change requests.

This document covers:

- `GET /api/hr/change-requests`
- `POST /api/hr/change-requests/:id/approve`
- `POST /api/hr/change-requests/:id/reject`

## Decision

Canonical frontend-facing runtime for HR change request review is:

- `Railway`

## Why Railway

This family requires all of the following:

1. authenticated JWT actor resolution
2. selected-context scope resolution
3. scoped HR write-role enforcement
4. controlled employee master writeback on approve
5. canonical HTTP error shaping

These are runtime-orchestration concerns, not Edge proxy concerns.

## Why Not Supabase Edge

This family is not a temporary adapter.

It should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime governance
- HR review permissions must align with app-route role gates
- employee master writeback plus audit append is business workflow logic

## Why Not DB/RPC As Frontend Runtime

`DB / RPC / direct Supabase client` may remain the internal substrate, but not the public runtime owner.

Reason:

- frontend-facing contract ownership must stay in one Railway family
- selected-context interpretation must not split between app layer and DB layer

## Runtime Rule

Phase 1 runtime rule:

- frontend calls Railway app routes only
- Railway owns actor resolution, selected-context resolution, and action gating
- DB tables remain the data substrate:
  - `employee_change_requests`
  - `employee_change_logs`
  - `employees`

## Action Semantics Decision

### List

- runtime owner: Railway
- DB substrate: `employee_change_requests`

### Approve

- runtime owner: Railway
- DB substrate:
  - read request from `employee_change_requests`
  - write employee master to `employees`
  - append audit row to `employee_change_logs`
  - update request to `approved`

### Reject

- runtime owner: Railway
- DB substrate:
  - update request to `rejected`
  - no employee master writeback
  - no audit log append

## Role Decision

Phase 1 canonical roles for HR review family:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Managers are intentionally excluded in Phase 1 because current app write governance does not include `manager`.

## Phase 1 Implementation Note

This family should prefer a transaction-minded apply path when the action routes are implemented.

Reason:

- approve touches three write targets in one logical action:
  - `employees`
  - `employee_change_logs`
  - `employee_change_requests`

That means runtime implementation should avoid partial-apply behavior.

## Temporary Compatibility

There is no separate MVP review family for HR change requests.

Canonical target is directly:

- `/api/hr/change-requests`

This avoids creating a second route family before Phase 1 review even begins.

## Non-goals

This runtime decision does not do:

- bulk approval
- notifications
- reject-reason persistence
- attendance correction review
- payroll governance
- recruiting workflow
