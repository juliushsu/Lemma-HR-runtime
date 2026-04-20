# Attendance Policy Phase 1 Governance v1

## Purpose

Define attendance policy as the next canonical organization settings / HR core family.

This Phase 1 governance document answers:

- what belongs to company-level attendance policy
- what may later become location-level override
- what is in scope now
- what is deferred
- what the canonical API family should be

## Canonical Runtime

Canonical frontend-facing runtime for attendance policy must be:

- `Railway`

Reason:

1. selected context resolution already lives in app runtime
2. organization settings write role enforcement must align with app role gates
3. policy write should stay in one canonical route family instead of splitting between app route and direct DB access
4. company-level defaults and future location-level overrides need one coherent contract owner

## Canonical Family

Phase 1 canonical API family should be:

- `GET /api/settings/attendance-policy`
- `PATCH /api/settings/attendance-policy`

This family is the attendance-policy counterpart to:

- `GET / PATCH /api/settings/company-profile`

It should not be mixed into:

- attendance event ingest
- attendance correction workflow
- location CRUD
- device binding families

## Phase 1 Minimal Scope

Phase 1 attendance policy should define only these policy concerns:

1. work policy type
2. attendance enablement switch
3. attendance adjustment permission policy
4. company default vs location override model

## Company-Level Settings

These fields belong to company-level attendance policy in Phase 1:

- `work_policy_type`
- `is_attendance_enabled`
- `hr_can_create_adjustment`
- `manager_can_create_adjustment`
- `employee_can_create_adjustment`

Recommended Phase 1 interpretation:

- `work_policy_type`
  - allowed values:
    - `two_day_weekend`
    - `public_holiday_off`
    - `fixed_shift`
    - `roster_based`
- `is_attendance_enabled`
  - company-wide attendance feature switch
- `hr_can_create_adjustment`
  - whether HR write actors may submit attendance corrections on behalf of an employee
- `manager_can_create_adjustment`
  - whether manager actors may submit attendance corrections for scoped employees
- `employee_can_create_adjustment`
  - Phase 1 default and recommendation: `false`

## Location-Level Override Boundary

These settings should remain eligible for future location-level override:

- `is_attendance_enabled`
- `checkin_radius_m`
- future attendance-boundary or check-in enforcement settings

Phase 1 decision:

- location override is part of the model
- but only the model boundary is defined now
- full location-level attendance policy write is deferred

`work_policy_type` is not required to support location override in Phase 1.

If location-level work-policy exceptions become necessary later, they should be introduced as an explicit Phase 2 decision instead of being silently embedded now.

## Scope Model

Phase 1 scope source must be:

- selected context + JWT only

Not allowed as truth:

- frontend-sent `org_id`
- frontend-sent `company_id`
- frontend-sent `branch_id`
- frontend-sent `environment_type`

Phase 1 route interpretation:

1. resolve actor from bearer JWT
2. resolve selected context server-side
3. resolve current company scope from selected context
4. apply company-level attendance policy inside that scope only

## Role Model

Phase 1 writable roles should match current organization settings write governance:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Not writable in Phase 1:

- `manager`
- `operator`
- `viewer`

Managers may later be granted attendance-adjustment operational permission by policy, but they are not attendance-policy settings writers.

## Work Policy Type Boundary

Phase 1 supports only the classification of work policy type.

Supported values:

- `two_day_weekend`
- `public_holiday_off`
- `fixed_shift`
- `roster_based`

Phase 1 does not include:

- roster generation
- shift assignment engine
- holiday calendar engine
- overtime rules engine
- payroll coupling

`roster_based` is allowed as a policy type value even though the scheduling engine remains deferred.

## Attendance Adjustment Permission Boundary

Phase 1 policy should explicitly define who may create attendance adjustments.

Recommended Phase 1 baseline:

- `hr_can_create_adjustment = true`
- `manager_can_create_adjustment = true`
- `employee_can_create_adjustment = false`

This is a policy-setting family, not the correction workflow itself.

It defines permission intent only.

It does not itself implement:

- approval workflow
- correction status transitions
- attachment upload flow

## Existing Substrate Alignment

Current read/runtime substrate already exposes adjacent attendance settings through:

- `GET /api/settings/company-profile`
  - company-level `is_attendance_enabled`
- `GET /api/settings/locations`
  - location-level `is_attendance_enabled`
  - location boundary fields
- `GET /api/hr/attendance/context`
  - resolved attendance context and effective boundary

Phase 1 attendance-policy governance does not replace these read surfaces immediately.

Instead, it creates the canonical settings family that future read/write convergence should target.

## Minimal API Shape Decision

Phase 1 minimal API family should be:

- `GET /api/settings/attendance-policy`
  - returns company-level attendance policy plus deferred location-override metadata
- `PATCH /api/settings/attendance-policy`
  - updates company-level attendance policy only

Recommended response should include:

- selected company identifiers
- current company policy values
- location override mode summary
- Phase 1 deferred markers where full location write is not yet available

## In Scope

Phase 1 is in scope for:

- company-level attendance policy contract
- work policy type selection
- `is_attendance_enabled`
- attendance adjustment permission flags
- company default vs location override governance rule
- canonical runtime decision
- source record

## Deferred

Deferred beyond Phase 1:

- full location-level attendance policy write
- roster / scheduling engine
- portal write
- RFID device API
- clock event ingest
- attendance correction workflow
- GPS / branch device binding
- attendance analytics / summaries
- payroll-coupled attendance rules

## Recommended Next Implementation Target

When implementation starts, the minimal first target should be:

- `GET / PATCH /api/settings/attendance-policy`

Phase 1 implementation should write only company-level policy fields first.

Location override write should remain deferred until the route family is stable and source records for location-level policy are added explicitly.
