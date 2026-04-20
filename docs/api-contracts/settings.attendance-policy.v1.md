# `GET / PATCH /api/settings/attendance-policy` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `PATCH`
- path: `/api/settings/attendance-policy`
- read schema version: `settings.attendance_policy.v1`
- write schema version: `settings.attendance_policy.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required

## 2. Canonical Runtime Rule

This is an organization settings family.

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- selected context is resolved server-side
- current company scope comes from selected context plus authenticated JWT
- frontend must not send `org_id`, `company_id`, `branch_id`, or `environment_type` as truth

## 3. Phase 1 Scope

This family manages company-level attendance policy only.

Phase 1 does not implement location-level policy write.

Phase 1 scope rule:

1. resolve selected context from server-side membership selection
2. require writable company scope
3. resolve target company from selected context only
4. reject any body/query scope field that attempts to override server scope truth

## 4. Allowed Roles

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Phase 1 read roles may include broader in-scope settings readers, but write must remain limited to the roles above.

Not writable in Phase 1:

- `manager`
- `operator`
- `viewer`

## 5. Canonical Data Model

Phase 1 company-level attendance policy includes:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `work_policy_type` | `string` | yes on write when included | allowed values below |
| `is_attendance_enabled` | `boolean` | no | company-wide attendance feature switch |
| `hr_can_create_adjustment` | `boolean` | no | whether HR may create attendance adjustments |
| `manager_can_create_adjustment` | `boolean` | no | whether managers may create attendance adjustments |
| `employee_can_create_adjustment` | `boolean` | no | Phase 1 recommended default is `false` |

Allowed `work_policy_type` values in Phase 1:

- `two_day_weekend`
- `public_holiday_off`
- `fixed_shift`
- `roster_based`

## 6. Company vs Location Interpretation

Phase 1 write target is company-level policy only.

Location-level override is represented as governance metadata, not as a writable Phase 1 payload.

Response may include:

- `location_override_mode`
  - example values:
    - `deferred`
    - `company_default_only`

Location-level fields reserved for future explicit override family:

- `is_attendance_enabled`
- `checkin_radius_m`

## 7. `GET /api/settings/attendance-policy`

### Purpose

Return canonical company-level attendance policy for the selected company scope.

### Success example

```json
{
  "schema_version": "settings.attendance_policy.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "attendance_policy": {
      "work_policy_type": "two_day_weekend",
      "is_attendance_enabled": true,
      "hr_can_create_adjustment": true,
      "manager_can_create_adjustment": true,
      "employee_can_create_adjustment": false
    },
    "location_override_mode": "deferred"
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-20T12:00:00.000Z"
  },
  "error": null
}
```

### Guaranteed success fields

- `data.org_id`
- `data.company_id`
- `data.attendance_policy`
- `data.location_override_mode`

## 8. `PATCH /api/settings/attendance-policy`

### Purpose

Update company-level attendance policy inside the selected company scope only.

### Writable fields

Request body may include:

- `work_policy_type`
- `is_attendance_enabled`
- `hr_can_create_adjustment`
- `manager_can_create_adjustment`
- `employee_can_create_adjustment`

At least one writable field must be provided.

### Validation rules

- body must be valid JSON
- `work_policy_type` must be one of:
  - `two_day_weekend`
  - `public_holiday_off`
  - `fixed_shift`
  - `roster_based`
- permission flags must be boolean when present
- at least one supported writable field must be present
- unsupported keys may be ignored, but must not be treated as authority inputs

### Phase 1 write behavior

Canonical behavior:

1. resolve actor from JWT
2. resolve selected context and writable company scope
3. load current company-level attendance policy row in scope
4. apply provided company-level fields only
5. return one canonical attendance-policy payload

### Success example

```json
{
  "schema_version": "settings.attendance_policy.update.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "attendance_policy": {
      "work_policy_type": "fixed_shift",
      "is_attendance_enabled": true,
      "hr_can_create_adjustment": true,
      "manager_can_create_adjustment": false,
      "employee_can_create_adjustment": false
    },
    "location_override_mode": "deferred"
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-20T12:00:00.000Z"
  },
  "error": null
}
```

## 9. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not writable by current actor |
| `400` | `INVALID_REQUEST` | invalid JSON, no writable field, or invalid field type/value |
| `404` | `COMPANY_NOT_FOUND` | selected company cannot be resolved in current scope |
| `500` | `CONFIG_MISSING` | required policy substrate missing |
| `500` | `INTERNAL_ERROR` | failed to load or update attendance policy |

## 10. Non-goals

This Phase 1 contract does not do:

- roster engine
- shift assignment engine
- portal write
- RFID device API
- clock event ingest
- attendance correction workflow
- GPS / branch device binding
- location-level attendance policy write
