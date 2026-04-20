# `GET / POST /api/hr/self/change-requests` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `POST`
- path: `/api/hr/self/change-requests`
- schema versions:
  - list: `hr.self.change_requests.list.v1`
  - create: `hr.self.change_requests.create.v1`
- auth requirement: `Authorization: Bearer <JWT>` required
- scope: resolved from server-side selected context plus authenticated user JWT
- canonical truth-source:
  - primary read/write target: `public.employee_change_requests`
  - self employee resolution anchor: `public.employees`
  - audit log rule reference: `public.employee_change_logs`

## 2. Canonical Rules

1. This family must not directly update `public.employees`.
2. `POST` only creates rows in `public.employee_change_requests`.
3. initial request status is always `pending`.
4. actor user and employee are resolved server-side.
5. frontend must not send `employee_id`, `requested_by`, `approved_by`, `status`, `org_id`, `company_id`, or `environment_type` as truth.
6. `employee_change_logs` is not written at request-creation time.
7. `employee_change_logs` is reserved for future approval/apply time, when an approved request actually changes employee master data.

## 3. Supported Fields In Phase 1

Only these `field_name` values are supported:

- `personal_email`
- `mobile_phone`
- `emergency_contact_name`
- `emergency_contact_phone`
- `preferred_name`

All other fields must be rejected.

## 4. Self Identity Resolution

The runtime must resolve self employee identity using:

1. authenticated user JWT
2. selected context
3. scoped employee binding inside the selected context

Current binding rule for this Phase 1 route:

- selected-context scoped employee rows are searched by `work_email` or `personal_email`
- the authenticated user's email is matched case-insensitively

If no employee binding can be resolved:

- return `400 EMPLOYEE_CONTEXT_REQUIRED`

If more than one scoped employee row matches:

- return `409 EMPLOYEE_BINDING_AMBIGUOUS`

## 5. `GET /api/hr/self/change-requests`

### Purpose

List self change requests for the server-resolved self employee only.

### Query params

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `status` | `pending \| approved \| rejected` | no | optional filter |

### Success example

```json
{
  "schema_version": "hr.self.change_requests.list.v1",
  "data": {
    "employee": {
      "id": "71000000-0000-0000-0000-000000000104",
      "employee_code": "DEMO-004"
    },
    "supported_fields": [
      "personal_email",
      "mobile_phone",
      "emergency_contact_name",
      "emergency_contact_phone",
      "preferred_name"
    ],
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
        "resolved_at": null
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

### Guaranteed success fields

- `data.employee.id`
- `data.employee.employee_code`
- `data.supported_fields`
- `data.items`

## 6. `POST /api/hr/self/change-requests`

### Purpose

Create one pending change request for the server-resolved self employee.

### Body

```json
{
  "field_name": "preferred_name",
  "new_value": "Emi"
}
```

### Body rules

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `field_name` | `string` | yes | must be one of the five supported fields |
| `new_value` | `string \| null` | yes | empty strings are normalized to `null`; `personal_email` is lowercased |

### Forbidden frontend-sent fields

These must be ignored or rejected as authority inputs:

- `employee_id`
- `requested_by`
- `approved_by`
- `status`
- `org_id`
- `company_id`
- `branch_id`
- `environment_type`
- `old_value`

### Create behavior

On create:

- server resolves actor user from JWT
- server resolves self employee from selected context + employee binding
- server reads current employee field value as `old_value`
- server writes a row to `employee_change_requests`
- server forces:
  - `status = pending`
  - `requested_by = auth user`
  - `approved_by = null`
  - `resolved_at = null`

### Success example

```json
{
  "schema_version": "hr.self.change_requests.create.v1",
  "data": {
    "employee": {
      "id": "71000000-0000-0000-0000-000000000104",
      "employee_code": "DEMO-004"
    },
    "item": {
      "id": "91000000-0000-0000-0000-000000000001",
      "employee_id": "71000000-0000-0000-0000-000000000104",
      "field_name": "preferred_name",
      "old_value": { "value": "Emily" },
      "new_value": { "value": "Emi" },
      "status": "pending",
      "requested_by": "81000000-0000-0000-0000-000000000001",
      "approved_by": null,
      "created_at": "2026-04-20T12:00:00.000Z",
      "resolved_at": null
    }
  },
  "meta": {
    "request_id": "22222222-2222-2222-2222-222222222222",
    "timestamp": "2026-04-20T12:00:00.000Z"
  },
  "error": null
}
```

## 7. `employee_change_logs` Rule

Phase 1 rule:

- `POST /api/hr/self/change-requests` does **not** create `employee_change_logs`
- log rows are deferred until future approve/apply flow
- a future approve/apply step must write:
  - `employee_id`
  - `field_name`
  - `old_value`
  - `new_value`
  - `actor_user_id`
  - `source = self` or `hr`, depending on the applied workflow action

This keeps request creation separate from actual employee master mutation.

## 8. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `400` | `EMPLOYEE_CONTEXT_REQUIRED` | no self employee binding in selected context |
| `400` | `INVALID_REQUEST` | invalid JSON or missing required fields |
| `400` | `UNSUPPORTED_CHANGE_FIELD` | field not in current five-field allowlist |
| `403` | `SCOPE_FORBIDDEN` | selected context not readable or self write blocked in current context |
| `409` | `EMPLOYEE_BINDING_AMBIGUOUS` | more than one scoped employee matched the authenticated user email |
| `409` | `NO_CHANGE_DETECTED` | requested value equals current employee master value |
| `500` | `CONFIG_MISSING` | service role config missing |
| `500` | `INTERNAL_ERROR` | failed to load employee or write request row |

## 9. UI Consumption Rules

- UI must treat this as a self-scoped family
- UI must not send `employee_id` as request authority
- UI may present one field change per request in Phase 1
- UI must not assume that creating a request means the employee master was updated
- if UI needs applied values, it must continue to read employee master separately
