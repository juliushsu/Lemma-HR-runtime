# Selected Context Rollout v1

## Purpose

This document defines the staging-first skeleton for introducing selected context and environment switching without changing production behavior yet.

## Migration Skeleton List

### 1) `20260414xxxx00_selected_context_session_v1.sql`

Purpose:

- add selected context persistence for staging-first rollout
- define helper functions for reading current selected membership

Suggested scope:

- `user_selected_contexts` table or equivalent
- unique current selection per user
- helper functions:
  - `get_selected_membership_id()`
  - `get_selected_context_v1()`

Notes:

- additive only
- no production enforcement switch in this migration

### 2) `20260414xxxx00_organization_access_mode_v1.sql`

Purpose:

- add explicit org policy labels

Suggested scope:

- `organizations.access_mode`
- allowed values:
  - `production_live`
  - `read_only_demo`
  - `sandbox_write`
- optional:
  - `is_protected_seed`
  - `seed_profile`

### 3) `20260414xxxx00_demo_protection_guardrails_staging_v1.sql`

Purpose:

- introduce staging-first helper rules for demo write denial

Suggested scope:

- helper functions:
  - `is_read_only_demo_org(p_org_id uuid)`
  - `can_select_membership(p_membership_id uuid)`
  - `can_write_selected_context(...)`

Notes:

- do not expand demo write access
- do not change production mutation behavior yet

### 4) `20260414xxxx00_selected_context_rls_helpers_staging_v1.sql`

Purpose:

- add context-aware read/write helpers without full production cutover

Suggested scope:

- `can_access_row_selected(...)`
- `can_read_scope_selected(...)`
- `can_write_scope_selected(...)`

Notes:

- keep old helpers temporarily
- allow side-by-side staging validation

## API Skeleton

### `GET /api/me` v2

Schema:

- `auth.me.v2`

Response must provide:

- `user`
- `memberships`
- `available_contexts`
- `current_context`
- `current_org`
- `current_company`
- `locale`
- `environment_type`

### `POST /api/session/context`

Schema:

- `auth.session.context.v1`

Request:

- `membership_id`

Response:

- `current_context`

## Readdy DTO Requirements

Readdy should expect these stable fields in `available_contexts[]`:

- `membership_id`
- `org_id`
- `org_slug`
- `org_name`
- `company_id`
- `company_name`
- `role`
- `scope_type`
- `environment_type`
- `access_mode`
- `writable`
- `is_default`

Readdy should expect these stable fields in `current_context`:

- `membership_id`
- `org_id`
- `company_id`
- `environment_type`
- `access_mode`
- `writable`

## RLS Convergence Order

### Step 1

- add selected context storage and helper functions
- do not replace existing helpers yet

### Step 2

- update staging-only API reads to prefer selected context
- continue returning v1-compatible data if needed

### Step 3

- apply selected-context-aware read helpers in staging
- verify no recursion or scope leakage

### Step 4

- apply selected-context-aware write helpers in staging
- explicitly deny writes for `read_only_demo`

### Step 5

- only after successful staging validation, consider production rollout plan

## Risks

- context mismatch between frontend-selected org and backend-evaluated membership
- accidental demo writes if helper layering is incomplete
- helper recursion if new functions re-query protected tables incorrectly
- stale cookies or session context after membership changes
- partial rollout where frontend expects `current_context` but backend still serves only implicit scope

## Smoke Validation Steps

### Read Path

1. User with one membership still resolves the expected current context
2. User with multiple memberships receives multiple `available_contexts`
3. Switching selected context changes `current_context`, `current_org`, and `environment_type`

### Write Path

1. Demo context returns `writable=false`
2. Demo mutation attempts remain denied
3. Staging-write context remains writable only for approved roles

### Isolation

1. Demo data remains visible when selected
2. Staging data remains separate when selected
3. No cross-org leakage when toggling contexts in one session

## Rollback Principle

- all rollout artifacts should be additive
- old helpers remain available until selected-context path is validated
- no destructive replacement of production helpers in this phase
