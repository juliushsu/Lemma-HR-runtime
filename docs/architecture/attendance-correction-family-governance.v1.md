# Attendance Correction Family Governance v1

## Purpose

Define attendance correction as the next canonical HR workflow family after attendance policy.

This document sets the Phase 1 governance boundary for:

- self correction request
- HR review queue
- approve / reject actions

It does not implement UI and does not expand into device ingest or scheduling logic.

## Canonical Families

Phase 1 canonical attendance correction families are:

- self family
  - `GET /api/hr/self/attendance-corrections`
  - `POST /api/hr/self/attendance-corrections`
- HR review family
  - `GET /api/hr/attendance-corrections`
  - `POST /api/hr/attendance-corrections/:id/approve`
  - `POST /api/hr/attendance-corrections/:id/reject`

These families should be treated as one canonical workflow family with two access surfaces:

- self requester surface
- scoped HR reviewer surface

## Canonical Runtime

Canonical frontend-facing runtime must be:

- `Railway`

Reason:

1. JWT actor resolution belongs in app runtime
2. selected context interpretation already lives in app runtime
3. employee binding resolution must be server-side
4. policy flags from attendance policy must be evaluated consistently with current selected company scope
5. approve applies append-only event logic plus correction status transition and should not split across frontend and DB layers

## Canonical Truth Sources

Phase 1 canonical data model uses:

- `public.attendance_corrections`
  - correction request truth
- `public.attendance_events`
  - append-only attendance event truth

Phase 1 rule:

- creating a correction request does not overwrite the original event
- approving a correction appends a correction event
- rejecting a correction does not append a correction event

## Self Applicant Rule

Phase 1 self applicant is not primarily a governance-role concept.

Canonical applicant interpretation is:

1. actor user is resolved from JWT
2. self employee is resolved from selected context + server-side employee binding
3. the request is allowed only if company attendance policy currently allows self correction create

Phase 1 self submit gate:

- `employee_can_create_adjustment = true`

If `employee_can_create_adjustment = false`, then:

- `POST /api/hr/self/attendance-corrections` must be forbidden

This means a user may have a high app role but still be blocked from self submit if the policy flag is false.

## HR / Manager Policy Flag Interpretation

Phase 1 attendance policy flags already exist:

- `employee_can_create_adjustment`
- `manager_can_create_adjustment`
- `hr_can_create_adjustment`

Their family-level interpretation is:

- `employee_can_create_adjustment`
  - governs self-family submit permission
- `manager_can_create_adjustment`
  - reserved for future delegated correction create flow
  - does not by itself grant review permission
- `hr_can_create_adjustment`
  - reserved for future HR-on-behalf create flow
  - does not by itself grant review permission

Phase 1 important boundary:

- manager / HR delegated create routes are deferred
- only self create is in scope now
- HR review remains a separate scoped review family

## Reviewer Rule

Phase 1 review visibility and review actions are intentionally owned by scoped HR write roles only:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Not reviewers in Phase 1:

- `manager`
- `operator`
- `viewer`

Reason:

- Phase 1 keeps attendance correction review under the same conservative review ownership model already used by other HR governance families
- `manager_can_create_adjustment` does not equal manager review authority

## Selected Context Rule

All attendance correction routes must use:

- selected context + JWT only

Not allowed as truth:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`
- frontend-sent `employee_id`
- frontend-sent `approved_by`

## Phase 1 Minimal Request Model

Phase 1 keeps the request model intentionally small.

Self request minimal payload should be:

- `original_event_id`
- `new_timestamp`
- `reason`

Phase 1 decision:

- `original_event_id` is required
- attachment upload is deferred
- missing-event creation without an original event is deferred

This avoids introducing ambiguous semantics for new clock-in / clock-out creation before the event model is fully converged.

## Phase 1 Minimal Response Model

Both self and HR list/read responses should minimally expose:

- request id
- employee id
- `original_event_id`
- `new_timestamp`
- `reason`
- `status`
- `created_by`
- `approved_by`
- `created_at`
- `resolved_at`

HR review list may additionally include:

- employee summary
- original event summary

## Approve Rule

Phase 1 approve must do all of the following:

1. verify request exists in selected scope
2. verify request status is `pending`
3. verify actor is a scoped review role
4. append one `attendance_events` row with:
   - `event_type = correction`
   - `source = correction`
   - `event_timestamp = new_timestamp`
5. update `attendance_corrections` row:
   - `status = approved`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

Phase 1 approve audit rule:

- yes, approve must write audit
- the audit record is the append-only correction event in `attendance_events`
- the approval actor is additionally captured on the correction row itself

## Reject Rule

Phase 1 reject must do all of the following:

1. verify request exists in selected scope
2. verify request status is `pending`
3. verify actor is a scoped review role
4. update `attendance_corrections` row:
   - `status = rejected`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

Phase 1 reject audit rule:

- reject does not append a correction event
- correction row action metadata is sufficient Phase 1 audit:
  - `approved_by`
  - `resolved_at`
  - `status = rejected`

## Re-entry Rule

Already resolved requests must not be re-operated.

If a request is already:

- `approved`
- or `rejected`

then:

- `approve` must return `409 REQUEST_ALREADY_RESOLVED`
- `reject` must return `409 REQUEST_ALREADY_RESOLVED`

## Existing Schema Compatibility

The repo already contains canonical schema documents for:

- `attendance_events`
- `attendance_corrections`

This governance document does not redefine those tables.

Instead, it defines the frontend-facing canonical route families that should sit on top of that schema.

## In Scope

Phase 1 is in scope for:

- self correction request list/create governance
- HR review list/approve/reject governance
- policy flag interpretation
- canonical runtime decision
- source record
- minimal request and response shape
- append-only approve audit rule

## Deferred

Deferred beyond Phase 1:

- GPS / device evidence enforcement
- RFID ingest
- roster / shift engine coupling
- portal write
- proof document upload
- manager delegated create route
- HR-on-behalf create route
- missing-event creation without `original_event_id`
- branch-level correction policy override
