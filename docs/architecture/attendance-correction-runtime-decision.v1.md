# Attendance Correction Runtime Decision v1

## Purpose

Define the canonical runtime for attendance correction operations.

This decision covers:

- `GET /api/hr/self/attendance-corrections`
- `POST /api/hr/self/attendance-corrections`
- `GET /api/hr/attendance-corrections`
- `POST /api/hr/attendance-corrections/:id/approve`
- `POST /api/hr/attendance-corrections/:id/reject`

## Decision

Canonical frontend-facing runtime for attendance correction is:

- `Railway`

## Why Railway

Attendance correction depends on:

1. authenticated JWT actor resolution
2. selected-context scope resolution
3. self employee binding resolution
4. company attendance-policy flag evaluation
5. scoped HR review-role enforcement
6. approve-time append-only event creation plus request state transition

These are app-runtime orchestration concerns and should stay in Railway.

## Why Not Supabase Edge

Attendance correction is not a proxy-only surface.

It should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime
- create permission depends on company policy flags interpreted in app scope
- self family and HR review family must share one contract owner

## Why Not DB/RPC As Frontend Runtime

`DB / RPC / direct Supabase client` may remain a future internal substrate, but it should not own the public contract.

Reason:

- frontend-facing workflow families should not split auth, scope, and actor interpretation between frontend and DB
- self create and HR approve/reject need one coherent route family

## Scope Decision

Phase 1 scope source is:

- selected context + JWT only

Not allowed:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`
- frontend-sent `employee_id`

## Role Decision

Phase 1 reviewer roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Phase 1 self create is governed by:

- self employee binding
- `employee_can_create_adjustment`

and not by governance role alone.

`manager_can_create_adjustment` and `hr_can_create_adjustment` are policy flags reserved for future delegated-create expansion, not current route ownership.

## Data Ownership Decision

This family owns the workflow contract on top of:

- `public.attendance_corrections`
- `public.attendance_events`

Phase 1 interpretation:

- request creation writes `attendance_corrections`
- approval writes:
  - `attendance_corrections`
  - one append-only `attendance_events` correction row
- rejection writes:
  - `attendance_corrections` only

## Consistency Decision

Approve touches more than one data target and must be treated as one logical apply path.

That means the implementation should avoid:

- correction marked `approved` but no correction event appended
- correction event appended but request status still `pending`

Phase 1 runtime should therefore prefer transaction-minded apply behavior for approve/reject actions.

## Temporary Compatibility

Existing operational attendance routes may continue to exist:

- `/api/hr/attendance/adjustments`

But they should not be treated as the canonical attendance correction family after this governance round.

Canonical target remains:

- `/api/hr/self/attendance-corrections`
- `/api/hr/attendance-corrections`

## Non-goals

This runtime decision does not include:

- GPS / device evidence validation
- RFID ingest
- roster engine coupling
- portal write
- proof document upload
- manager delegated correction create
- HR-on-behalf correction create
