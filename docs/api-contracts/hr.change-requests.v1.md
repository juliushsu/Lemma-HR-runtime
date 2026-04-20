# `GET / POST /api/hr/change-requests*` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `POST`
- family:
  - `GET /api/hr/change-requests`
  - `POST /api/hr/change-requests/:id/approve`
  - `POST /api/hr/change-requests/:id/reject`
- schema versions:
  - list: `hr.change_requests.list.v1`
  - action: `hr.change_requests.action.v1`
- auth requirement: `Authorization: Bearer <JWT>` required
- selected context rule:
  - scope must be resolved from server-side selected context plus authenticated JWT
  - frontend must not send `org_id`, `company_id`, `branch_id`, or `environment_type` as truth
- canonical truth-source:
  - request table: `public.employee_change_requests`
  - audit table: `public.employee_change_logs`
  - employee master writeback target: `public.employees`

## 2. Canonical Review Rules

1. HR review routes are scope-governed HR routes, not self-service routes.
2. Review actions must never trust frontend-sent `approved_by`, `status`, `employee_id`, or scope fields as truth.
3. Only `pending` requests are actionable.
4. `approved` or `rejected` requests must not be re-approved or re-rejected.
5. `approve` is the only Phase 1 point where employee master writeback is allowed for this family.
6. `reject` must not update `employees`.
7. `employee_change_logs` is append-only and is only written when an approval actually applies a change.

## 3. Allowed Roles

Phase 1 review visibility and action permission are intentionally the same:

- allowed scoped roles:
  - `owner`
  - `super_admin`
  - `org_super_admin`
  - `admin`

Not allowed in Phase 1:

- `manager`
- `operator`
- `viewer`
- self-only actors

Reason:

- review queue data contains employee master-data change requests
- Phase 1 keeps review ownership on scoped HR write roles only

## 4. Supported Request Fields In Phase 1

This review family only guarantees apply/reject support for requests created on these fields:

- `personal_email`
- `mobile_phone`
- `emergency_contact_name`
- `emergency_contact_phone`
- `preferred_name`

If a request exists outside this allowlist, Phase 1 review runtime must reject action with `409 UNSUPPORTED_CHANGE_FIELD`.

## 5. `GET /api/hr/change-requests`

### Purpose

List employee change requests inside the selected HR scope.

### Query params

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `status` | `pending \| approved \| rejected \| all` | no | default is `pending` |
| `employee_id` | `string` | no | optional scoped filter |
| `field_name` | `string` | no | optional filter for one supported field |

### Server-side rules

- selected context is resolved on the server
- request scope is resolved from selected context plus JWT
- only scoped HR write roles may read this review queue
- if `status` is omitted, the route returns `pending` requests only

### Success example

```json
{
  "schema_version": "hr.change_requests.list.v1",
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
        "field_name": "preferred_name",
        "old_value": { "value": "Emily" },
        "new_value": { "value": "Emi" },
        "status": "pending",
        "requested_by": "81000000-0000-0000-0000-000000000001",
        "approved_by": null,
        "created_at": "2026-04-20T12:00:00.000Z",
        "resolved_at": null,
        "employee": {
          "id": "71000000-0000-0000-0000-000000000104",
          "employee_code": "DEMO-004"
        }
      }
    ]
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-20T12:00:00.000Z"
  },
  "error": null
}
```

## 6. `POST /api/hr/change-requests/:id/approve`

### Purpose

Approve one pending employee change request and apply it to employee master data.

### Request body

Phase 1 body is empty.

Frontend must not send:

- `approved_by`
- `employee_id`
- `field_name`
- `status`
- `old_value`
- `new_value`

### Approve behavior

When a pending request is approved, the runtime must perform this canonical state transition:

1. resolve actor user from JWT
2. resolve selected context and verify scoped HR write permission
3. load the target request from `employee_change_requests`
4. verify:
   - request exists in scope
   - request status is `pending`
   - request field is in the Phase 1 allowlist
5. write the approved value into `public.employees`
6. append one row to `public.employee_change_logs`
7. update the request row:
   - `status = approved`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

### `employee_change_logs` write rule on approve

On approval, the runtime must append one log row with:

- `employee_id`
- `field_name`
- `old_value`
- `new_value`
- `actor_user_id = approver JWT user`
- `source = self`

Phase 1 interpretation:

- `source = self` reflects that the change originated from a self-service request
- the HR approver identity is carried by `actor_user_id`

### Employee master update timing

Phase 1 rule:

- `employees` is updated at approve time, not at request create time

### Success example

```json
{
  "schema_version": "hr.change_requests.action.v1",
  "data": {
    "action": "approve",
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "status": "approved",
      "approved_by": "81000000-0000-0000-0000-000000000099",
      "resolved_at": "2026-04-20T12:05:00.000Z"
    },
    "log": {
      "field_name": "preferred_name",
      "source": "self"
    }
  },
  "meta": {
    "request_id": "22222222-2222-2222-2222-222222222222",
    "timestamp": "2026-04-20T12:05:00.000Z"
  },
  "error": null
}
```

## 7. `POST /api/hr/change-requests/:id/reject`

### Purpose

Reject one pending employee change request without applying employee master writeback.

### Request body

Phase 1 body is empty.

### Reject reason rule

Phase 1 decision:

- reject reason is **not required**
- reject reason is **not persisted**

Reason:

- `employee_change_requests` Phase 1 schema does not include a canonical `reject_reason` column
- this round does not expand schema

### Reject behavior

When a pending request is rejected, the runtime must:

1. resolve actor user from JWT
2. resolve selected context and verify scoped HR write permission
3. load the target request from `employee_change_requests`
4. verify request status is `pending`
5. update the request row:
   - `status = rejected`
   - `approved_by = actor_user_id`
   - `resolved_at = now()`

Reject must not:

- update `employees`
- insert `employee_change_logs`

### Success example

```json
{
  "schema_version": "hr.change_requests.action.v1",
  "data": {
    "action": "reject",
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "status": "rejected",
      "approved_by": "81000000-0000-0000-0000-000000000099",
      "resolved_at": "2026-04-20T12:05:00.000Z"
    }
  },
  "meta": {
    "request_id": "33333333-3333-3333-3333-333333333333",
    "timestamp": "2026-04-20T12:05:00.000Z"
  },
  "error": null
}
```

## 8. Repeat Action Rule

Approved or rejected requests must not be actioned again.

If `status != pending`, both action routes must return:

- `409 REQUEST_ALREADY_RESOLVED`

This applies to:

- approve after approve
- reject after reject
- approve after reject
- reject after approve

## 9. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not writable by the current actor |
| `404` | `CHANGE_REQUEST_NOT_FOUND` | request id does not exist in current scope |
| `409` | `REQUEST_ALREADY_RESOLVED` | request is already approved or rejected |
| `409` | `UNSUPPORTED_CHANGE_FIELD` | request field is outside the Phase 1 allowlist |
| `500` | `CONFIG_MISSING` | service role config missing |
| `500` | `INTERNAL_ERROR` | failed to load request, write employee, write log, or update request |

## 10. Phase 1 Non-goals

This contract does not do:

- bulk approval
- notification delivery
- reject-reason persistence
- field-level approval matrix
- multi-step approval workflow
- attendance correction review
