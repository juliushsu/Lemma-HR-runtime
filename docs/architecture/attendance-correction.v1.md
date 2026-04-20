# Attendance Correction v1

## Purpose

Define the Phase 1 canonical attendance-correction model.

This schema introduces a clean separation between:

- append-only attendance events
- correction requests that do not overwrite the raw event

## Canonical Tables

- `public.attendance_events`
- `public.attendance_corrections`

Legacy MVP tables such as `attendance_logs` and `attendance_adjustments` are not removed in this round.

## Core Rules

1. Raw attendance history is append-only.
2. A correction is a separate governance object, not an in-place overwrite.
3. Original events remain preserved even after approval.
4. Approval metadata belongs on `attendance_corrections`, not on the raw event row.

## Minimal Event Model

Phase 1 only uses:

- event types:
  - `clock_in`
  - `clock_out`
  - `correction`
- event sources:
  - `device`
  - `manual`
  - `correction`

No schedule engine, geofence evidence, or shift interpretation is added here.

## Minimal Correction Status Model

- `pending`
- `approved`
- `rejected`

This is enough for Phase 1 governance without introducing workflow-engine complexity.

## RLS

Phase 1 uses basic scope-and-self rules:

- event read:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- event insert:
  - scoped HR writers
  - or self-authenticated employee append
- correction read:
  - scoped readers
  - or self employee
- correction insert:
  - scoped HR writers
  - or self-authenticated pending correction request
- correction update:
  - scoped HR writers only

No update/delete policy is added for `attendance_events`, preserving append-only semantics.

## Existing Schema Overlap

The repo already contains:

- `attendance_logs`
- `attendance_adjustments`

Phase 1 does not attempt a data migration or runtime cutover. It only establishes the canonical target schema for future convergence.

## Non-goals

This round does not do:

- attendance device integration
- shift policy engine
- lateness calculation
- payroll linkage
- manager UI
- public observability dashboard
