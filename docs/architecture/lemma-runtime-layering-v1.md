# Lemma Runtime Layering v1

Status: architecture inventory and policy proposal

Purpose:

- classify where current runtime responsibility lives across Railway, Supabase Edge Functions, and direct DB / RPC / Supabase client usage
- make temporary runtime overrides explicit
- identify where current API families are layered correctly and where they are drifting
- define a minimum runtime policy for future reclassification decisions

Scope:

- frontend-facing API families under `app/api/**`
- documented temporary runtime overrides
- direct DB / RPC usage that already acts as the real business-rule substrate behind HTTP routes

This document reflects:

- current app route inventory in this repo
- current API contract and source-governance docs
- the documented temporary employee detail runtime override to Supabase edge

## Layer Definitions

### Railway

- Next.js app routes under `app/api/**`
- owns HTTP envelope, selected-context resolution, auth/session handling, preview override behavior, and frontend contract shaping

### Supabase Edge Functions

- external function runtime used outside this repo when a frontend-facing route is temporarily or permanently served from edge
- must be treated as a separate runtime source with its own deploy trace and source record

### Direct DB / RPC / Supabase client

- Postgres schema, RPC functions, RLS, and scoped Supabase client reads/writes
- may be the real substrate for workflow or read-model logic
- should not automatically become the frontend contract surface just because the logic lives there

## Runtime Inventory

| API family | Current runtime target | Canonical design source | Current runtime status | Should instead be | Main reason | Current risk |
| --- | --- | --- | --- | --- | --- | --- |
| `/api/me` | Railway app route | [`app/api/me/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/me/route.ts) | canonical | Railway | auth/session orchestration | auth divergence if moved away from Railway-selected context handling |
| employee detail `GET / PATCH` | split runtime: `GET` currently treated as Supabase edge `api-hr-employees`; `PATCH` is Railway app route | [`app/api/hr/employees/[id]/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/[id]/route.ts) plus [employee source record](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/source-records/hr.employees.detail.v1.md) | temporary override for `GET`; canonical for `PATCH` | Railway | auth/session orchestration and contract ownership | dual runtime, source unresolved, contract drift, auth divergence |
| employee list `/api/hr/employees` | Railway app route | [`app/api/hr/employees/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/route.ts) | canonical | Railway | lightweight read-model shaping with scope-aware auth | duplicated mapping logic if list/detail/runtime families diverge |
| org chart `/api/hr/org-chart` | Railway app route with Supabase table reads | [`app/api/hr/org-chart/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/org-chart/route.ts) | canonical | Railway | lightweight read-model shaping | duplicated mapping logic and contract drift if tree-building moves into multiple runtimes |
| leave requests family | dual Railway families: imperative service-role routes under `/api/hr/leave-requests/*` and RPC-backed routes under `/api/hr/leave/requests/*` | split across [`app/api/hr/leave-requests/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/leave-requests/route.ts) and [`app/api/hr/leave/requests/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/leave/requests/route.ts) | non-canonical dual runtime within Railway | Railway | workflow/business rule | dual runtime, contract drift, duplicated mapping logic |
| leave approval actions | dual Railway families: imperative service-role approval routes under `/api/hr/leave-requests/[id]/*` and RPC-backed routes under `/api/hr/leave/requests/[id]/*` | split across [`app/api/hr/leave-requests/[id]/approve/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/leave-requests/[id]/approve/route.ts) and [`app/api/hr/leave/requests/[id]/approve/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/leave/requests/[id]/approve/route.ts) | non-canonical dual runtime within Railway | Railway | workflow/business rule | dual runtime, contract drift, duplicated mapping logic |
| language skills | Railway app routes delegating to DB RPC | [`app/api/hr/employees/[id]/language-skills/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/[id]/language-skills/route.ts) and related DB RPC calls | canonical, intentionally layered | Railway | lightweight read-model shaping over DB-owned write logic | duplicated mapping logic if frontend bypasses Railway and contract ownership becomes unclear |
| departments / positions | Railway app routes with direct scoped table reads; departments also writable via Railway | [`app/api/hr/departments/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/departments/route.ts), [`app/api/hr/positions/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/positions/route.ts) | canonical | Railway | internal lookup/read-only plus small master-data writes | contract drift and master-governance split if these are consumed directly from DB by frontend |
| debug / observability related endpoints | Railway internal audit endpoint for LINE audit; raw access logging lives in DB; central error pool not yet implemented | [`app/api/integrations/line/audit/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/integrations/line/audit/route.ts), [`public.api_access_logs` migration](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/supabase/migrations/20260408101000_staging_beta_lock_security_setup.sql:48), [error events proposal](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/error-events-foundation-v1.md) | mixed: audit route exists, raw logs exist, central error pool is still proposal-only | Railway for internal audit surfaces; DB/RPC/direct client for raw storage | internal lookup/read-only and temporary proxy for observability gaps | source unresolved for future error ingest, duplicated mapping logic, no unified error pipeline |

## Family Notes

### `/api/me`

- This is the clearest Railway-owned surface in the repo.
- It resolves selected context, emits staging debug headers, and shapes the auth/session payload for the frontend.
- This family should not move to edge unless edge becomes the canonical auth/session orchestrator, which it is not today.

### Employee detail `GET / PATCH`

- This is currently the clearest example of runtime drift.
- Canonical design source is Railway.
- Current live integration state treats `GET` as temporarily served by Supabase edge `api-hr-employees`.
- `PATCH` remains Railway-owned.
- Even if the temporary edge runtime now returns the nested contract shape, this is still not governance closure because the family is split across runtimes.

### Employee list

- Employee list is currently a straightforward Railway read-model endpoint.
- It performs scope enforcement and light enrichment across departments, positions, and managers.
- There is no strong reason to move this family to edge while employee detail remains Railway-owned by design.

### Org chart

- Org chart is a good example of Railway doing lightweight shaping over normalized tables.
- It is read-only, but it still depends on selected context, auth, and consistent DTO shaping.
- If tree-building later moves into DB/RPC, Railway should still remain the frontend contract layer.

### Leave requests and approval actions

- Leave is currently the largest layering inconsistency inside Railway itself.
- There are two parallel route families:
  - `/api/hr/leave-requests/*`
  - `/api/hr/leave/requests/*`
- One family uses service-role orchestration and snapshot assembly.
- The other family uses DB RPC as the business-rule core.
- This is a real dual-runtime problem even though both are still deployed through Railway.

### Language skills

- Language skills are the cleanest current example of the preferred mixed model:
  - Railway owns auth, scope, HTTP envelope, and contract
  - DB RPC owns mutation semantics and read/write validation
- This family should remain Railway at the frontend boundary.

### Departments / positions

- These are master-data families with simple reads and limited writes.
- They can remain thin Railway routes.
- They should not be exposed as direct client DB reads for frontend product traffic because that would split governance from employee detail and org chart consumers.

### Debug / observability

- Current observability is fragmented:
  - `public.api_access_logs` exists
  - `public.error_events` does not yet exist as a real runtime table
  - `LINE audit` exists as a Railway internal endpoint
- This means the platform has storage for access logging, but not a unified frontend-debuggable error event layer yet.

## Recommended Runtime Policy v1

### What MUST stay in Railway

- Any frontend-facing endpoint that resolves auth/session context
- Any endpoint that depends on selected context, preview override, or membership gating
- Any endpoint that assembles a canonical response contract across multiple tables
- Any workflow mutation with multi-step authorization or state transitions

Examples:

- `/api/me`
- employee detail GET/PATCH
- employee list
- org chart
- leave requests and approval actions

### What MAY live in Edge

- Temporary runtime proxies during controlled migration, but only if they are explicitly recorded as temporary overrides in a source record
- Narrow read-only surfaces where edge is intentionally designated as the canonical implementation source
- Transitional compatibility layers that preserve the canonical contract while Railway is being repaired or reclassified

Constraints:

- edge must have a contract doc
- edge must have a source record
- edge deploy source must be traceable
- edge must not silently diverge from the documented canonical response shape

### What SHOULD NOT be wrapped as API

- Raw internal logging tables such as `public.api_access_logs`
- Internal helper RPC that only exists to support a Railway-owned contract
- Read-only internal tables or lookup material that do not need a separate frontend-facing contract

Preferred rule:

- if the value is only useful as a subordinate substrate for a Railway-owned endpoint, keep it as DB / RPC, not a separate product API

## Immediate Reclassification Candidates

1. **Employee detail GET**
   Current state is a temporary Supabase edge override over a Railway-designed contract.
   This should be reclassified back to canonical Railway runtime first.

2. **Employee detail family as a whole**
   `GET` and `PATCH` should return to one runtime family and one source of deploy truth.

3. **Leave requests family**
   Converge `/api/hr/leave-requests/*` and `/api/hr/leave/requests/*` into one canonical family.

4. **Leave approval action family**
   Converge approve / reject / cancel actions onto the same canonical leave runtime strategy as list/detail/create.

5. **Debug / observability surfaces**
   Formalize one policy:
   - Railway for internal audit endpoints
   - DB for raw log storage
   - no ad hoc product-facing debug APIs without contract and source governance

## Practical Summary

- Railway should remain the canonical frontend contract layer for core HR APIs.
- Edge is acceptable only as an explicitly documented temporary override or a deliberately canonicalized edge surface.
- DB/RPC should own durable business rules and storage semantics, but should not silently replace frontend API ownership.
- The biggest current layering risks are:
  - employee detail split across Railway design and edge runtime
  - leave split across two parallel Railway families
  - observability split across raw log storage, internal audit surfaces, and proposal-only error-event design
