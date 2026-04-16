# Preview Context Override v1

## Purpose

This proposal introduces a preview-safe context override path so cross-origin preview can validate:

- UI environment switching
- context-sensitive read views
- environment labeling and scope rendering

without weakening the canonical first-party selected-context contract.

## Problem

Lemma now has two different execution environments for frontend validation:

- first-party / same-site runtime
- cross-origin preview runtime such as `https://readdy.ai`

The canonical selected-context model is cookie-based:

- `POST /api/session/context`
- backend writes `lemma_selected_membership_id`
- later `GET /api/me` and other routes resolve from that server-owned cookie

That remains correct for first-party runtime, but it is not stable as the only verification path for cross-site preview because browser third-party cookie policy may block or discard the selected-context cookie even when:

- `credentials: "include"` is present
- `SameSite=None`
- `Secure`
- `HttpOnly`

## Design Goal

Adopt a dual-mode model:

- preview mode validates read-only context switching without cookie persistence
- first-party mode keeps canonical cookie-based selected-context persistence

This preserves the current contract while giving preview a safe, explicit, non-persistent override path.

## Non-Goals

This proposal does not:

- replace `POST /api/session/context`
- replace cookie-based persistence
- add writable preview support
- make preview authoritative for mutations
- merge demo and staging semantics

## Canonical Rule

The canonical selected-context contract remains unchanged:

1. `POST /api/session/context`
2. backend writes selected-context cookie
3. subsequent requests resolve current context from server-owned persistence

This path remains the only production-grade selected-context mechanism.

## Preview Override Rule

Preview may use a request-scoped override that applies only to the current request.

Supported input:

- header: `x-preview-context`
- query: `_preview_ctx`

Meaning:

- value must be a `membership_id`
- backend validates that the authenticated user actually owns that membership
- if valid, backend resolves the request using that membership for this request only

Preview override must:

- never write `lemma_selected_membership_id`
- never mutate selected-context cookie state
- never become higher priority than canonical session in first-party runtime
- never expand access beyond the authenticated user's memberships

## Activation Conditions

Preview override becomes eligible only when one of these conditions is true:

1. `Origin` exactly matches `ALLOW_PREVIEW_ORIGIN`
2. `ALLOW_PREVIEW_CONTEXT_OVERRIDE=true`

Recommended default:

- `ALLOW_PREVIEW_ORIGIN=https://readdy.ai`
- `ALLOW_PREVIEW_CONTEXT_OVERRIDE=false` in normal environments
- `ALLOW_PREVIEW_CONTEXT_OVERRIDE=true` only in staging or deliberate preview validation

## Precedence

To avoid contract drift, precedence should be:

1. preview override, but only when preview mode is explicitly allowed
2. canonical selected-context cookie
3. existing bootstrap fallback order

Rationale:

- preview needs deterministic per-request switching even when browser cookie persistence is unavailable
- first-party runtime still behaves exactly as before when preview override is absent

## Read-Only Enforcement

Preview override is always read-only.

When preview override is active:

- `current_context.writable = false`
- access mode is coerced to read-only behavior for authorization decisions
- mutation routes must reject with a dedicated preview-read-only error

Recommended error shape:

- code: `PREVIEW_READ_ONLY`
- message: `Preview context override is read-only`

## Environment Variables

Add:

- `ALLOW_PREVIEW_ORIGIN`
- `ALLOW_PREVIEW_CONTEXT_OVERRIDE`
- `PREVIEW_FORCE_READ_ONLY`

Recommended staging values:

- `ALLOW_PREVIEW_ORIGIN=https://readdy.ai`
- `ALLOW_PREVIEW_CONTEXT_OVERRIDE=true`
- `PREVIEW_FORCE_READ_ONLY=true`

Recommended first-party production values:

- `ALLOW_PREVIEW_ORIGIN=`
- `ALLOW_PREVIEW_CONTEXT_OVERRIDE=false`
- `PREVIEW_FORCE_READ_ONLY=true`

## Minimal Runtime Shape

The minimal runtime shape should add preview metadata into context resolution, not into frontend-specific route logic.

Suggested internal shape extension:

- `preview_override_active: boolean`
- `preview_override_membership_id: string | null`
- `preview_origin_allowed: boolean`
- `effective_read_only: boolean`

These fields are internal first. They do not need to become contract fields in this round.

## Minimal Patch Plan

### 1. Shared preview helper

Add a small helper in `app/api/_selected_context.ts`:

- read `Origin`
- read `x-preview-context`
- read `_preview_ctx`
- decide whether preview override is eligible
- validate the target membership against the authenticated user's memberships
- return either:
  - `null` when preview override is inactive
  - the request-scoped selected membership id when active

This helper should not write cookies.

### 2. Shared selected-context resolver

Update `load_selected_context_bundle()` in `app/api/_selected_context.ts` to:

- consult preview override before cookie lookup
- keep cookie lookup unchanged when preview override is absent
- mark preview override state internally
- coerce writable to `false` when preview override is active and `PREVIEW_FORCE_READ_ONLY=true`

### 3. HR access helper

Update `app/api/hr/_lib.ts` so `resolve_current_context()` and `can_write()` honor the same preview override and read-only coercion.

This keeps HR read routes preview-aware without changing their external contract.

### 4. Legal access helper

Update `app/api/legal/_lib.ts` in the same way as HR:

- request-scoped context override allowed for read routes
- write guard hard-denies preview override mutations

### 5. No contract changes to session route

Do not change `app/api/session/context/route.ts`.

That endpoint remains:

- canonical
- cookie-based
- first-party contract

Preview override is not a replacement for that route.

## Routes That Should Support Preview Override

These routes are read-oriented and should resolve current context from preview override when active.

### Core context

- `GET /api/me`

### HR read routes

- `GET /api/hr/employees`
- `GET /api/hr/employees/:id`
- `GET /api/hr/employees/:id/language-skills`
- `GET /api/hr/departments`
- `GET /api/hr/positions`
- `GET /api/hr/org-chart`
- `GET /api/hr/leave/requests`
- `GET /api/hr/leave/requests/:id`
- `GET /api/hr/attendance/logs`
- `GET /api/hr/attendance/daily-summary`
- `GET /api/hr/attendance/context`

### Legal read routes

- `GET /api/legal/documents`
- `GET /api/legal/documents/:id`
- `GET /api/legal/cases`
- `GET /api/legal/cases/:id`
- `GET /api/legal/cases/:id/documents`

### Portal read routes

- `GET /api/portal/overview`
- `GET /api/portal/people-insights`
- `GET /api/portal/org-health`
- `GET /api/portal/ai-insights`
- `GET /api/portal/compliance`
- `GET /api/portal/compliance/:item_id`
- `GET /api/portal/notifications`
- `GET /api/portal/notifications/:item_id`

### Operational read routes

- `GET /api/locations`
- `GET /api/attendance-logs`
- `GET /api/attendance-sources`
- `GET /api/attendance-sources/:id/locations`
- `GET /api/settings/company-profile`
- `GET /api/settings/locations`
- `GET /api/system/current-plan`
- `GET /api/system/features`

## Routes That Must Explicitly Reject Preview Override

These routes must not honor preview override for mutation behavior.

### Canonical context persistence

- `POST /api/session/context`

### HR mutations

- `POST /api/hr/employees`
- `PATCH /api/hr/employees/:id`
- `POST /api/hr/employees/:id/language-skills`
- `DELETE /api/hr/employees/:id/language-skills/:skill_id`
- `POST /api/hr/departments`
- `POST /api/hr/leave/requests`
- `POST /api/hr/leave/requests/:id/approve`
- `POST /api/hr/leave/requests/:id/reject`
- `POST /api/hr/leave/requests/:id/cancel`
- `POST /api/hr/attendance/check`
- `POST /api/hr/attendance/adjustments`
- `POST /api/hr/attendance/imports/upload-preview`
- `POST /api/hr/attendance/imports/:batch_id/confirm`
- `POST /api/hr/attendance/external-api/sources`
- `POST /api/hr/attendance/external-api/batches/:batch_id/confirm`

### Legal mutations

- `POST /api/legal/documents`
- `POST /api/legal/documents/:id/versions`
- `POST /api/legal/cases`
- `POST /api/legal/cases/:id/documents`
- `POST /api/legal/storage/upload-url`

### Operational mutations

- `POST /api/locations`
- `PATCH /api/locations/:id`
- `POST /api/attendance-logs/check`
- `POST /api/attendance-sources/bootstrap`
- `PATCH /api/attendance-sources/:id`
- `PUT /api/attendance-sources/:id/locations`
- `PATCH /api/system/features/:feature_key`

### External / integration / webhook routes

- `POST /api/intake/request`
- `POST /api/integrations/line/binding-token`
- `POST /api/integrations/line/binding-token/verify`
- `POST /api/integrations/line/bindings`
- `POST /api/integrations/line/webhook`
- `POST /api/hr/attendance/external-api/inbound`

## Verification Plan

### Preview verification

Use preview override only for read flow validation:

1. call `GET /api/me?_preview_ctx=<membership_id>` from allowed preview origin
2. confirm `current_context.membership_id` reflects override
3. confirm `current_context.writable = false`
4. call one HR read route under the same override
5. call one Legal or Portal read route under the same override
6. confirm any mutation route returns `PREVIEW_READ_ONLY` or equivalent denial

### First-party verification

Canonical flow must remain unchanged:

1. `POST /api/session/context`
2. server writes cookie
3. `GET /api/me`
4. current context persists without preview override

## Phase 1 Implementation Boundary

This document is the long-term architecture basis, but the currently landed Phase 1 runtime is intentionally smaller than the full target list above.

### Phase 1 implemented now

- `GET /api/me`
- HR read routes that already resolve through `app/api/hr/_lib.ts`
- Legal read routes that already resolve through `app/api/legal/_lib.ts`
- preview read-only enforcement inside shared HR and Legal write guards

### Not yet implemented in Phase 1

- Portal read routes
- settings read routes
- system read routes
- non-HR / non-Legal operational read routes outside the shared selected-context helpers

These routes remain outside the current preview-safe support boundary until a later phase explicitly wires them to the same helper model.

## Validation Responsibility Split

### Preview is responsible for

- UI workspace switching behavior
- request-scoped context rendering correctness
- read-path scope changes across supported `GET` routes
- confirming preview override never grants writable behavior
- confirming supported mutations fail with `PREVIEW_READ_ONLY`

### Preview is not responsible for

- cookie persistence
- browser acceptance of selected-context cookies
- session continuity across requests without explicit preview override
- final validation of canonical selected-context persistence

### First-party is responsible for

- `POST /api/session/context`
- cookie-based selected-context persistence
- cross-request session continuity
- final validation of authoritative current workspace
- final validation of write behavior in non-preview runtime

## Rollout Recommendation

Do this in two phases:

### Phase 1

- land helper design
- wire preview override into shared context resolution helpers only
- support `GET /api/me` plus existing HR and Legal read helpers

### Phase 2

- add explicit preview rejection for remaining mutation routes
- document error code and smoke checklist
- validate preview against Readdy and first-party against staging frontend

## CTO Summary

Preview should become:

- a read-only, request-scoped context simulation layer

First-party should remain:

- the only persistence-grade selected-context environment

That separation lets Lemma keep fast preview iteration without misusing cross-site preview as the final authority for session persistence.
