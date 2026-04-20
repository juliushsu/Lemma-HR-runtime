# API Debug Drawer v1

Status: minimal internal debug UI spec

Purpose:

- define the minimum owner-facing API debug drawer used during internal validation
- make API/runtime/debug context visible without requiring a full observability system
- give owner, super admin, and internal QA one lightweight place to inspect current API interpretation

This document defines a minimal internal tool specification.
It does not implement runtime behavior in this round.

## 1. Intended Users

This drawer is for internal and privileged use only.

Allowed users:

- owner
- super_admin
- test mode account
- internal QA account

This drawer is not intended for normal employee users.

## 2. Display Location

Minimum UI behavior:

- show a bug button at the bottom-right corner of every page
- clicking the bug button opens a drawer
- the drawer should be visually lightweight and fast to open
- the drawer should expose current API/debug interpretation without forcing navigation to a separate page

Recommended interaction model:

- bug button remains available while the user stays in an allowed internal role
- drawer can be opened and closed repeatedly without page refresh

## 3. Minimum Fields

The drawer must show the following minimum groups.

### 3.1 Current Context

Show:

- `user_id`
- `role`
- `org_id`
- `company_id`
- `environment_type`
- `writable`
- `employee_id`

Purpose:

- let internal users confirm who the backend believes they are
- surface selected-context interpretation in one visible place
- expose whether the current view is read-only or writable

### 3.2 Request Info

Show:

- `last_endpoint`
- `method`
- `status`
- `request_id`
- `runtime_target`

Purpose:

- show which API was last called
- show whether the response came from Railway, Edge, or another explicitly named runtime target
- allow fast correlation between UI behavior and backend request identity

### 3.3 Identity Interpretation

Show:

- `actor_source`
- `employee_binding_source`
- `selected_context_used`

Minimum semantic meaning:

- `actor_source`
  - where the acting identity came from
  - example: authenticated JWT user
- `employee_binding_source`
  - how employee identity was resolved
  - example: scoped employee binding
- `selected_context_used`
  - whether the selected context was actually used during interpretation

Purpose:

- help internal users detect auth drift
- make it obvious when a route is still using a transitional identity rule

### 3.4 Scope Interpretation

Show:

- `scope_mode`
- `effective_org_id`
- `effective_company_id`
- `effective_environment_type`
- `fallback_used`

Allowed `scope_mode` values:

- `self`
- `all`
- `none`

Purpose:

- show the effective scope that actually governed the last API call
- make fallback behavior explicit instead of invisible

### 3.5 Error Info

Show:

- `canonical_error_code`
- `message`
- `timestamp`

Purpose:

- expose the latest canonical API failure in a human-readable but governance-aligned format
- prefer canonical backend error codes over free-form UI error text

## 4. Behavior Rules

The drawer should follow these minimum rules:

- it is a UI-visible inspection tool, not a standalone admin dashboard
- it should reflect the most recent API request/response context relevant to the current page session
- it should prefer canonical error code and request metadata over inferred UI-only messages
- it should help answer:
  - who am I
  - what endpoint did I just call
  - which runtime handled it
  - how identity and scope were interpreted
  - what canonical error happened, if any

## 5. Non-Goals

This round explicitly does not include:

- complete observability system
- dashboard
- production public exposure
- persistent error pool

Additional non-goals for this round:

- no alerting system
- no metrics backend
- no cross-session error history
- no automatic retry logic

## 6. Phase Split

### Phase 1

UI-visible debug drawer only.

Scope:

- render the bug button
- open the drawer
- show current context
- show most recent request info
- show identity interpretation
- show scope interpretation
- show latest canonical error block

Phase 1 is intentionally local and visible.
It is meant to reduce debugging ambiguity during owner/internal QA usage.

### Phase 2

Optional API event bridge / error pool integration.

Possible future additions:

- bridge request/error events into a normalized API event stream
- integrate with future error pool or event storage when that foundation exists
- add deeper correlation between request_id and centralized failure records

Phase 2 is optional.
It must not block Phase 1.

## 7. Decision Summary

The minimum API Debug Drawer should be:

- internal only
- bottom-right bug button plus drawer
- focused on current context, request info, identity interpretation, scope interpretation, and canonical error info
- explicitly not a full observability platform

This keeps the tool small enough to ship quickly while still being useful for owner and QA debugging.
