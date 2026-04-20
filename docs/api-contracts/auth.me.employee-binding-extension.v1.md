# `GET /api/me` Employee Binding Extension v1

## Purpose

Define the minimum extension needed if `GET /api/me` should become a reliable debug and session truth-source for employee-bound workflows.

This document is contract guidance only.
It does not change runtime behavior in this round.

## 1. Why `/api/me` Is Currently Insufficient

Current `/api/me` output includes:

- `user`
- `memberships`
- `available_contexts`
- `current_context`
- `current_org`
- `current_company`
- `locale`
- `environment_type`

This is enough for:

- auth/session presence
- selected-context inspection
- workspace switching
- basic writable/read-only gating

This is not enough for:

- employee-bound debug flows
- self-service actor validation
- approver actor validation
- API debug drawer visibility into employee binding state

Current gap:

- `/api/me` does not expose whether the authenticated user resolved to an employee in the selected context
- `/api/me` does not expose the resolved `employee_id`
- `/api/me` does not expose how the binding was resolved

As a result, downstream tools may misread:

- "employee binding is missing in runtime"

when the real issue is only:

- "`/api/me` does not currently return employee binding output"

## 2. Proposed New Fields

Add a new top-level block under `data`:

```json
{
  "employee_binding": {
    "resolved": true,
    "employee_id": "uuid",
    "employee_code": "SBX-EMP-0002",
    "binding_source": "selected_context.scoped_email_match"
  }
}
```

### 2.1 Minimum Fields

Required fields for the extension block:

- `employee_binding.resolved`
- `employee_binding.employee_id`
- `employee_binding.employee_code`
- `employee_binding.binding_source`

### 2.2 Field Meaning

#### `employee_binding.resolved`

Type:

- `boolean`

Meaning:

- whether the current authenticated user resolved to exactly one employee inside the current selected context

#### `employee_binding.employee_id`

Type:

- `uuid | null`

Meaning:

- resolved employee UUID inside the selected context

#### `employee_binding.employee_code`

Type:

- `string | null`

Meaning:

- resolved employee code for display/debug convenience

#### `employee_binding.binding_source`

Type:

- `string`

Recommended initial values:

- `selected_context.scoped_email_match`
- `selected_context.requested_employee_id`
- `none`

Meaning:

- the server-side rule used to derive the employee binding

## 3. Binding Truth-Source

The employee binding truth-source should remain server-side only.

It should not be derived from frontend state.

Recommended truth-source:

- selected context
- scoped employee lookup within that context
- authenticated user email matched against `employees.work_email` or `employees.personal_email`

This should align with the current leave-family resolver pattern already used in backend code:

- resolve the active selected context first
- list employees inside that selected scope
- resolve employee by authenticated user email match within that scoped employee set

This means `/api/me` should reuse the same server-side binding interpretation already used by employee-bound leave flows, rather than inventing a new parallel resolver.

## 4. Accounts That May Legitimately Be Null

`employee_binding` may be null-like or unresolved for some account classes.

Recommended rule:

- `resolved = false`
- `employee_id = null`
- `employee_code = null`
- `binding_source = "none"`

Valid examples:

- pure platform operator accounts
- internal inspection accounts without employee rows
- portal/test accounts that are intentionally auth-valid but not employee-bound
- future system accounts used only for governance or smoke inspection

This is especially important for accounts such as:

- platform/internal users who may pass beta lock but are not part of employee master

These accounts should not be treated as data errors merely because no employee row exists.

## 5. Backward Compatibility

This extension should be additive only.

Rules:

- existing clients that ignore `employee_binding` must continue to work
- current `auth.me.v1` / `auth.me.v2` core fields remain unchanged
- the new block should be optional for older clients and required only for debug-aware consumers

Recommended compatibility behavior:

- if runtime has not implemented binding output yet, old clients continue using current fields
- once implemented, debug-aware consumers should prefer `data.employee_binding`
- clients must not infer employee binding from `memberships[0]` or from arbitrary UI state

## 6. Suggested Success Shape

Illustrative shape:

```json
{
  "schema_version": "auth.me.v2",
  "data": {
    "user": {},
    "memberships": [],
    "available_contexts": [],
    "current_context": {},
    "current_org": {},
    "current_company": {},
    "locale": "zh-TW",
    "environment_type": "sandbox",
    "employee_binding": {
      "resolved": true,
      "employee_id": "7192bc97-a81e-4b9d-861b-0aa816039d43",
      "employee_code": "SBX-EMP-0002",
      "binding_source": "selected_context.scoped_email_match"
    }
  },
  "error": null
}
```

Illustrative unresolved shape:

```json
{
  "employee_binding": {
    "resolved": false,
    "employee_id": null,
    "employee_code": null,
    "binding_source": "none"
  }
}
```

## 7. Debug / Session Value

With this extension, `/api/me` can more safely act as:

- current session truth-source
- current selected-context truth-source
- employee-binding truth-source for debug UI

This is especially useful for:

- API Debug Drawer
- owner/internal QA account inspection
- leave self-service and approver debugging
- distinguishing provisioning failures from response-shaping gaps

## 8. Non-Goals

This round explicitly does not include:

- provisioning changes
- employee binding schema changes
- alternate binding model design
- replacing selected-context governance
- frontend implementation work

Direct non-goal:

- do not change account provisioning in this round

## 9. Summary

If `/api/me` is expected to serve as debug/session truth-source, it should expose:

- whether employee binding resolved
- which employee was resolved
- which server-side binding rule was used

The binding truth-source should remain:

- selected context
- server-side scoped employee lookup
- authenticated email-based binding within that scope

This keeps `/api/me` aligned with current backend employee-bound workflow behavior while staying additive and backward compatible.
