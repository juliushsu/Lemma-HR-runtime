# Attendance Policy Runtime Decision v1

## Purpose

Define the canonical runtime for attendance policy operations.

This decision covers:

- `GET /api/settings/attendance-policy`
- `PATCH /api/settings/attendance-policy`

## Decision

Canonical frontend-facing runtime for attendance policy is:

- `Railway`

## Why Railway

Attendance policy depends on:

1. authenticated JWT actor resolution
2. selected-context company scope resolution
3. organization settings write-role enforcement
4. canonical response shaping for one settings family
5. future convergence between company-level defaults and location-level override metadata

These are app-runtime orchestration concerns and should stay in Railway.

## Why Not Supabase Edge

Attendance policy is not a proxy-only surface.

It should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime
- organization settings role gates already live in app runtime
- this family needs one stable public contract owner before any future DB/RPC substrate hardening

## Why Not DB/RPC As Frontend Runtime

`DB / RPC / direct Supabase client` may remain a future internal substrate, but it should not own the public contract.

Reason:

- frontend-facing settings families should not split scope interpretation between frontend, DB, and app route
- company-level policy and future location override metadata should remain under one Railway-owned contract family

## Scope Decision

Phase 1 scope source is:

- selected context + JWT only

Not allowed:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`

The selected company context is the only canonical target company for this family.

## Role Decision

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Managers are intentionally excluded from settings write governance even if future attendance-adjustment policy may grant them operational correction power.

## Data Ownership Decision

Phase 1 company-level attendance policy should own these fields:

- `work_policy_type`
- `is_attendance_enabled`
- `hr_can_create_adjustment`
- `manager_can_create_adjustment`
- `employee_can_create_adjustment`

Phase 1 future location-level override candidates:

- `is_attendance_enabled`
- `checkin_radius_m`

Location override write is deferred and must not be folded into the first family implementation without an explicit contract expansion.

## Contract Boundary Decision

The canonical public family should be:

- `/api/settings/attendance-policy`

This avoids spreading attendance policy across:

- company profile route
- locations route
- attendance context route
- attendance adjustments route

Those routes may continue to expose adjacent operational data, but attendance policy governance should converge toward the dedicated settings family above.

## Phase 1 Decision

Phase 1 includes:

- work policy type classification
- attendance feature enablement
- attendance-adjustment permission flags
- company default / location override governance rule

Phase 1 does not include:

- roster engine
- scheduling engine
- portal write
- RFID / device APIs
- clock event ingest
- attendance correction workflow
- GPS / branch device binding
- location-level policy write

## Temporary Compatibility

Existing read surfaces may temporarily remain:

- `GET /api/settings/company-profile`
- `GET /api/settings/locations`
- `GET /api/hr/attendance/context`

But these should be treated as adjacent read substrate, not as the canonical attendance-policy family.

Canonical target remains:

- `GET / PATCH /api/settings/attendance-policy`
