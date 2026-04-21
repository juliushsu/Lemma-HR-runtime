# `GET / POST /api/hr/self/attendance-corrections*` and `GET / POST /api/hr/attendance-corrections*` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `POST`
- family:
  - `GET /api/hr/self/attendance-corrections`
  - `POST /api/hr/self/attendance-corrections`
  - `GET /api/hr/attendance-corrections`
  - `POST /api/hr/attendance-corrections/:id/approve`
  - `POST /api/hr/attendance-corrections/:id/reject`
- schema versions:
  - self list: `hr.self.attendance_corrections.list.v1`
  - self create: `hr.self.attendance_corrections.create.v1`
  - review list: `hr.attendance_corrections.list.v1`
  - review action: `hr.attendance_corrections.action.v1`
- auth requirement: `Authorization: Bearer <JWT>` required

## 2. Canonical Runtime Rule

This is a canonical HR workflow family.

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- selected context is resolved server-side
- actor user is resolved from authenticated JWT
- employee binding is resolved server-side
- frontend must not send `org_id`, `company_id`, `branch_id`, `environment_type`, `employee_id`, or `approved_by` as truth

## 3. Canonical Truth Sources

- correction request truth:
  - `public.attendance_corrections`
- append-only attendance truth:
  - `public.attendance_events`

Phase 1 rules:

1. creating a correction request does not overwrite attendance history
2. only approval appends a `correction` attendance event
3. reject never appends a correction event

## 4. Self Applicant Rule

`POST /api/hr/self/attendance-corrections` is allowed only when all of the following are true:

1. actor is authenticated
2. self employee binding resolves in selected context
3. selected company attendance policy has:
   - `employee_can_create_adjustment = true`

Phase 1 self family is not opened by:

- `manager_can_create_adjustment`
- `hr_can_create_adjustment`

Those flags are reserved for future delegated-create flows, not this self family.

## 5. Reviewer Rule

`GET /api/hr/attendance-corrections` and review actions are allowed only for scoped review roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Not reviewers in Phase 1:

- `manager`
- `operator`
- `viewer`

## 6. `GET /api/hr/self/attendance-corrections`

### Purpose

List correction requests created by the current self employee in the selected context.

### Query params

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `status` | `pending \| approved \| rejected \| all` | no | default `all` |

### Success example

```json
{
  "schema_version": "hr.self.attendance_corrections.list.v1",
  "data": {
    "employee": {
      "id": "71000000-0000-0000-0000-000000000104"
    },
    "items": [
      {
        "id": "91000000-0000-0000-0000-000000000001",
        "employee_id": "71000000-0000-0000-0000-000000000104",
        "original_event_id": "81000000-0000-0000-0000-000000000001",
        "new_timestamp": "2026-04-21T09:03:00.000Z",
        "reason": "traffic delay",
        "status": "pending",
        "created_by": "61000000-0000-0000-0000-000000000001",
        "approved_by": null,
        "created_at": "2026-04-21T09:10:00.000Z",
        "resolved_at": null
      }
    ]
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

## 7. `POST /api/hr/self/attendance-corrections`

### Purpose

Create one pending attendance correction request for the current self employee.

### Minimal Phase 1 payload

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `original_event_id` | `string` | yes | Phase 1 requires an existing event to correct |
| `new_timestamp` | `string` | yes | ISO timestamp |
| `reason` | `string` | yes | trimmed, non-empty |

Phase 1 intentionally does not support:

- `attachment_url`
- proof document upload
- missing-event create with no `original_event_id`

### Server-side rules

- actor user comes from JWT
- target employee comes from selected context + self employee binding
- runtime must verify company attendance policy currently allows self correction create
- request must be inserted as:
  - `status = pending`
  - `approved_by = null`
  - `resolved_at = null`

### Success example

```json
{
  "schema_version": "hr.self.attendance_corrections.create.v1",
  "data": {
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "employee_id": "71000000-0000-0000-0000-000000000104",
      "original_event_id": "81000000-0000-0000-0000-000000000001",
      "new_timestamp": "2026-04-21T09:03:00.000Z",
      "reason": "traffic delay",
      "status": "pending",
      "created_by": "61000000-0000-0000-0000-000000000001",
      "approved_by": null,
      "created_at": "2026-04-21T09:10:00.000Z",
      "resolved_at": null
    }
  },
  "meta": {
    "request_id": "22222222-2222-2222-2222-222222222222",
    "timestamp": "2026-04-21T12:05:00.000Z"
  },
  "error": null
}
```

## 8. `GET /api/hr/attendance-corrections`

### Purpose

List correction requests in the selected HR review scope.

### Query params

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `status` | `pending \| approved \| rejected \| all` | no | default `pending` |
| `employee_id` | `string` | no | optional scoped filter |

### Success example

```json
{
  "schema_version": "hr.attendance_corrections.list.v1",
  "data": {
    "scope": {
      "org_id": "11000000-0000-0000-0000-000000000001",
      "company_id": "22000000-0000-0000-0000-000000000001",
      "environment_type": "sandbox"
    },
    "filters": {
      "status": "pending"
    },
    "items": [
      {
        "id": "91000000-0000-0000-0000-000000000001",
        "employee_id": "71000000-0000-0000-0000-000000000104",
        "original_event_id": "81000000-0000-0000-0000-000000000001",
        "new_timestamp": "2026-04-21T09:03:00.000Z",
        "reason": "traffic delay",
        "status": "pending",
        "created_by": "61000000-0000-0000-0000-000000000001",
        "approved_by": null,
        "created_at": "2026-04-21T09:10:00.000Z",
        "resolved_at": null,
        "employee": {
          "id": "71000000-0000-0000-0000-000000000104",
          "employee_code": "SBX-EMP-0001"
        }
      }
    ]
  },
  "meta": {
    "request_id": "33333333-3333-3333-3333-333333333333",
    "timestamp": "2026-04-21T12:10:00.000Z"
  },
  "error": null
}
```

## 9. `POST /api/hr/attendance-corrections/:id/approve`

### Purpose

Approve one pending attendance correction request.

### Request body

Phase 1 body is empty.

### Approve behavior

Canonical behavior:

1. resolve actor user from JWT
2. resolve selected context and verify scoped review permission
3. load the request in scope
4. verify request status is `pending`
5. append one `attendance_events` row with:
   - `employee_id = request.employee_id`
   - `event_type = correction`
   - `event_timestamp = request.new_timestamp`
   - `source = correction`
   - `created_by = actor_user_id`
6. update request row:
   - `status = approved`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

### Approve audit rule

Approve must write audit.

Phase 1 audit sources are:

- append-only correction event in `attendance_events`
- review metadata on `attendance_corrections`

### Success example

```json
{
  "schema_version": "hr.attendance_corrections.action.v1",
  "data": {
    "action": "approve",
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "status": "approved",
      "approved_by": "61000000-0000-0000-0000-000000000099",
      "resolved_at": "2026-04-21T12:20:00.000Z"
    },
    "event": {
      "event_type": "correction",
      "source": "correction"
    }
  },
  "meta": {
    "request_id": "44444444-4444-4444-4444-444444444444",
    "timestamp": "2026-04-21T12:20:00.000Z"
  },
  "error": null
}
```

## 10. `POST /api/hr/attendance-corrections/:id/reject`

### Purpose

Reject one pending attendance correction request.

### Request body

Phase 1 body is empty.

### Reject behavior

Canonical behavior:

1. resolve actor user from JWT
2. resolve selected context and verify scoped review permission
3. load the request in scope
4. verify request status is `pending`
5. update request row:
   - `status = rejected`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

Reject must not:

- append `attendance_events`
- overwrite any original event

### Reject audit rule

Reject does not append a correction event.

Phase 1 audit is the resolved request row itself:

- `status = rejected`
- `approved_by`
- `resolved_at`

### Success example

```json
{
  "schema_version": "hr.attendance_corrections.action.v1",
  "data": {
    "action": "reject",
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "status": "rejected",
      "approved_by": "61000000-0000-0000-0000-000000000099",
      "resolved_at": "2026-04-21T12:25:00.000Z"
    }
  },
  "meta": {
    "request_id": "55555555-5555-5555-5555-555555555555",
    "timestamp": "2026-04-21T12:25:00.000Z"
  },
  "error": null
}
```

## 11. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not accessible or writable |
| `403` | `EMPLOYEE_CONTEXT_REQUIRED` | self employee binding cannot be resolved |
| `403` | `ATTENDANCE_CORRECTION_CREATE_FORBIDDEN` | company policy does not allow create for this flow |
| `400` | `INVALID_REQUEST` | invalid JSON or invalid field type/value |
| `404` | `CORRECTION_NOT_FOUND` | target request not found in scope |
| `409` | `REQUEST_ALREADY_RESOLVED` | request is already approved or rejected |
| `500` | `INTERNAL_ERROR` | failed to load or mutate correction workflow state |

## 12. Non-goals

This Phase 1 contract does not do:

- GPS / device evidence validation
- RFID ingest
- roster engine coupling
- portal write
- proof document upload
- manager delegated correction create
- HR-on-behalf correction create
