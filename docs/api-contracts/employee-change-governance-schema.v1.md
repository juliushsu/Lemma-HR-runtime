# Employee Change Governance Schema Contract v1

## Purpose

Record the canonical Phase 1 database contract for employee master-data governance.

## Tables

### `public.employee_change_requests`

Key columns:

- `id`
- `employee_id`
- `field_name`
- `old_value`
- `new_value`
- `status`
- `requested_by`
- `approved_by`
- `created_at`
- `resolved_at`

Indexes:

- `employee_change_requests_scope_status_idx`
- `employee_change_requests_employee_idx`

### `public.employee_change_logs`

Key columns:

- `id`
- `employee_id`
- `field_name`
- `old_value`
- `new_value`
- `actor_user_id`
- `source`
- `created_at`

Indexes:

- `employee_change_logs_scope_created_idx`
- `employee_change_logs_employee_idx`

## RLS Contract

### Requests

- select:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- insert:
  - scoped HR write
  - or self-created pending request
- update:
  - scoped HR write only

### Logs

- select:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- insert:
  - scoped HR write
  - or self-authored log row with `source = 'self'`

No delete policy is defined in Phase 1.

## Phase 1 Compatibility Notes

- This contract does not define API routes.
- This contract does not implement automatic writeback into `employees`.
