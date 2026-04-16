# Leave MVP Approval Closure Staging Smoke v1

Status: implemented

## Goal

Verify the leave MVP runtime slice can complete a controlled staging loop without expanding beyond leave routes:

1. create request
2. read detail
3. approve or reject current step
4. re-read detail
5. verify list and drawer-level contract alignment

This smoke targets the MVP routes:

- `POST /api/hr/leave-requests`
- `GET /api/hr/leave-requests`
- `GET /api/hr/leave-requests/:id`
- `POST /api/hr/leave-requests/:id/approve`
- `POST /api/hr/leave-requests/:id/reject`

It does not target:

- canonical `/api/hr/leave/requests` routes
- attendance
- preview override
- non-leave HR modules

## Preconditions

- staging backend is deployed
- writable staging account is available
- selected-context cookie or same-site authenticated session is already established
- target company scope has a valid requester employee
- target company scope has a valid manager chain for approval

## Expected Contract Boundary

### List route

`GET /api/hr/leave-requests`

Expected shape:

- top-level `resolved_locale`
- top-level `locale_source`
- `data.items[]`
- item summary fields only:
  - `id`
  - `status`
  - `current_step`

List is the summary source.

### Drawer/detail route

`GET /api/hr/leave-requests/:id`

Expected shape:

- `id`
- `employee_id`
- `leave_type`
- `reason`
- `start_at`
- `end_at`
- `status`
- `current_step`
- `created_at`
- `resolved_locale`
- `locale_source`
- `approval_steps[]`

`approval_steps[]` must include:

- `id`
- `step_order`
- `approver_employee_id`
- `approver`
- `status`
- `acted_at`
- `comment`

This is the drawer / detail truth source.

### Mutation routes

`POST /api/hr/leave-requests`

- must return the same detail-like snapshot shape as drawer
- must keep canonical keys only

`POST /api/hr/leave-requests/:id/approve`

- must return updated detail-like snapshot
- if next step exists, `current_step` increments
- if no next step exists, request `status` becomes `approved`

`POST /api/hr/leave-requests/:id/reject`

- must return updated detail-like snapshot
- request `status` becomes `rejected`
- current approval step `status` becomes `rejected`

## Controlled Smoke Sequence

### Path A: approve then reject

Use when the requester has at least two approvers in chain.

1. `POST /api/hr/leave-requests`
   - expect `201`
   - capture `data.id`
   - expect `data.approval_steps.length >= 2`

2. `GET /api/hr/leave-requests/:id`
   - expect `200`
   - expect same `id`
   - expect `approval_steps[0].status = pending`

3. `POST /api/hr/leave-requests/:id/approve`
   - body must contain current `approver_employee_id`
   - expect `200`
   - expect `current_step = 1`
   - expect first approval step status becomes `approved`

4. `GET /api/hr/leave-requests/:id`
   - expect `current_step = 1`
   - expect next step still `pending`

5. `POST /api/hr/leave-requests/:id/reject`
   - body must contain current step `approver_employee_id`
   - body must contain rejection `comment`
   - expect `200`
   - expect request `status = rejected`

6. `GET /api/hr/leave-requests`
   - expect created request appears in list
   - expect summary `status = rejected`

### Path B: direct reject

Use when only one current approver is available for smoke.

1. `POST /api/hr/leave-requests`
   - expect `201`

2. `GET /api/hr/leave-requests/:id`
   - expect `200`

3. `POST /api/hr/leave-requests/:id/reject`
   - use current step `approver_employee_id`
   - include rejection `comment`
   - expect `200`
   - expect request `status = rejected`

4. `GET /api/hr/leave-requests`
   - expect created request appears in list with `status = rejected`

## Contract Mismatch Triage

If smoke fails, classify issues in this order:

1. `create/detail mismatch`
   - create response does not match drawer snapshot shape

2. `detail/approve mismatch`
   - approve or reject response omits `approval_steps`, locale hint, or approver snapshot

3. `detail/list mismatch`
   - list summary does not reflect the same request status/current_step after mutation

4. `manager-chain data issue`
   - request creation fails due to broken or missing manager chain in selected scope

Only fix leave slice issues in this smoke round.

## Script Support

For repeatable staging smoke, use:

- `scripts/smoke/leave_mvp_approval_closure_staging.sh`

That script intentionally targets only the MVP leave routes above.
