# Leave Truth-Source Matrix v1

Status: runtime-aligned

Purpose:

- define the current leave runtime truth source
- prevent frontend/runtime drift across canonical vs MVP routes
- prevent re-interpretation of `submitted`, `approval_status`, and `status`

This document is a short alignment document. It does not introduce new runtime behavior.

## 1. Endpoint Matrix

### 1.1 Canonical leave route

Canonical leave route family:

- `GET /api/hr/leave/requests`
- `POST /api/hr/leave/requests`
- `GET /api/hr/leave/requests/:id`
- `POST /api/hr/leave/requests/:id/approve`
- `POST /api/hr/leave/requests/:id/reject`
- `POST /api/hr/leave/requests/:id/cancel`

Role:

- canonical leave domain route family
- RPC-backed runtime route
- broader HR/admin leave workflow contract
- supports scope, filter, pagination, and canonical leave domain payloads

Canonical schema version examples:

- `hr.leave.request.list.v1`
- `hr.leave.request.detail.v1`
- `hr.leave.request.create.v1`
- `hr.leave.request.approve.v1`
- `hr.leave.request.reject.v1`

### 1.2 Current self-service MVP route

Current self-service MVP route family:

- `GET /api/hr/leave-requests`
- `POST /api/hr/leave-requests`
- `GET /api/hr/leave-requests/:id`
- `POST /api/hr/leave-requests/:id/approve`
- `POST /api/hr/leave-requests/:id/reject`

Role:

- current staging-first employee-facing / self-service MVP runtime slice
- locale-hint-enabled route family
- detail snapshot includes:
  - `status`
  - `current_step`
  - `approval_steps`
  - `resolved_locale`
  - `locale_source`

Schema version examples:

- `hr.leave_request_mvp.list.v1`
- `hr.leave_request_mvp.create.v1`
- `hr.leave_request_mvp.detail.v1`
- `hr.leave_request_mvp.approve.v1`
- `hr.leave_request_mvp.reject.v1`

### 1.3 Truth-source rule

Current truth-source rule:

- canonical leave truth source for the domain remains `/api/hr/leave/requests/*`
- current self-service MVP runtime truth source remains `/api/hr/leave-requests/*`

These two route families are not interchangeable.

Frontend must not:

- silently switch between the two families
- merge payload assumptions from both families
- treat them as one contract unless a future convergence document explicitly says so

## 2. Canonical Status Allowlist

Current runtime-aligned allowlist:

- `pending`
- `approved`
- `rejected`
- `cancelled`

Interpretation:

- `pending` is the formal initial runtime value
- `approved` is the formal final approval value
- `rejected` is the formal rejection value
- `cancelled` is the formal cancellation value

### 2.1 Submitted is not current runtime truth

`submitted` may still appear in older proposal documents, but it should not be treated as the current runtime truth-source status.

For current runtime alignment:

- use `pending`
- do not introduce new frontend branching based on `submitted`
- do not map `submitted` as if it were a current runtime response requirement

### 2.2 approval_status vs status

Current alignment rule:

- MVP self-service slice treats `status` as the primary employee-facing workflow key
- canonical leave routes may still expose `approval_status` as part of the broader domain payload

Frontend must not assume:

- `approval_status` always exists on MVP routes
- `status` and `approval_status` can be mixed without route-family awareness

## 3. Self-Service Access Rule

Self-service history must require employee context.

The backend should not use missing employee context as a reason to show all leave requests inside the selected company scope.

Required rule:

- if employee context cannot be resolved for self-service history, backend should return a scoped failure or an empty result
- backend should not fallback to company-wide leave history for employee self-service

Reason:

- employee self-service history is narrower than HR/admin leave read scope
- broad fallback would leak unrelated requests inside the same company scope

## 4. Transitional Compatibility

The following are still transitional compatibility areas:

1. dual route families
   - canonical `/api/hr/leave/requests/*`
   - MVP `/api/hr/leave-requests/*`

2. dual status vocabulary in older documents
   - historical proposal wording may still mention `submitted`
   - runtime truth should use `pending`

3. mixed field vocabulary
   - canonical routes may expose `approval_status`
   - MVP self-service routes center on `status`

These are transitional compatibility realities, not permission to blur contracts.

## 5. Not Runtime Truth-Source

The following should not be treated as current runtime truth-source on their own:

- older proposal documents that still use `submitted`
- frontend assumptions that merge canonical and MVP leave routes
- UI-specific interpretations of `approval_status` vs `status`
- smoke documents from one route family applied to the other without explicit mapping

If runtime and frontend need one unified leave contract later, that must be written as a separate convergence document.
