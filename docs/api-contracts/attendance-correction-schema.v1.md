# Attendance Correction Schema Contract v1

## Purpose

Record the canonical Phase 1 database contract for attendance correction governance.

## Tables

### `public.attendance_events`

Key columns:

- `id`
- `employee_id`
- `event_type`
- `event_timestamp`
- `source`
- `created_by`
- `created_at`

Indexes:

- `attendance_events_employee_timestamp_idx`
- `attendance_events_scope_timestamp_idx`

### `public.attendance_corrections`

Key columns:

- `id`
- `employee_id`
- `original_event_id`
- `new_timestamp`
- `reason`
- `attachment_url`
- `status`
- `created_by`
- `approved_by`
- `created_at`
- `resolved_at`

Indexes:

- `attendance_corrections_employee_status_idx`
- `attendance_corrections_scope_status_idx`

## RLS Contract

### Attendance Events

- select:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- insert:
  - scoped HR write
  - or self-authenticated append

No update/delete policy is defined in Phase 1.

### Attendance Corrections

- select:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- insert:
  - scoped HR write
  - or self-authenticated pending correction request
- update:
  - scoped HR write only

## Phase 1 Compatibility Notes

- Existing `attendance_logs` and `attendance_adjustments` remain in place.
- This contract defines the canonical target schema only.
