# Lemma Runtime Governance Rule v1

Status: formal runtime governance rule

Purpose:

- prevent frontend-facing API families from drifting across Railway, Supabase Edge, and DB / RPC layers without an explicit ownership decision
- ensure Readdy, Codex, and CTO use the same runtime classification rule before frontend integration begins
- stop the failure mode where canonical design source, deployed runtime source, and frontend-called runtime all differ

Scope:

- all frontend-facing API families
- all temporary runtime overrides
- all staging, sandbox, and future production-facing runtimes
- all DB / RPC or direct Supabase client paths that may be proposed as frontend-facing runtime

Relationship to other governance docs:

- API contract truth-source remains under `docs/api-contracts/`
- API source traceability remains governed by `docs/api-contracts/api-source-governance.v1.md`
- this document governs **runtime classification and placement**

## 1. Runtime Layers

### Railway

- Next.js app routes under `app/api/**`
- owns HTTP envelope, auth/session resolution, selected context, preview override, canonical contract shaping, and workflow orchestration

### Supabase Edge Functions

- external function runtime used outside this repo when a frontend-facing API family is intentionally or temporarily served from edge
- must be treated as a separate runtime source with separate deploy traceability

### DB / RPC / Direct Supabase Client

- Postgres schema, RLS, SQL functions, RPCs, and direct Supabase reads/writes
- may own durable business logic or internal read substrate
- does not automatically become a valid frontend-facing runtime just because logic exists there

## 2. Mandatory Pre-Frontend Decision Rule

Before any frontend-facing API family is connected to frontend consumption, one runtime classification must be chosen explicitly:

- `Railway`
- `Supabase Edge`
- `DB / RPC / direct Supabase client`

If runtime classification is not decided and recorded, frontend integration must not start.

Required record:

- the runtime choice must appear in either:
  - a route source record
  - a runtime decision record
  - or both

Minimum required fields for the decision:

- API family name
- current runtime
- canonical runtime
- source repo/path
- contract doc path
- deploy target
- deploy method

## 3. Prohibited States

The following are not allowed as steady-state governance:

- one frontend-facing API family split across multiple runtimes for normal operation
- a temporary runtime override without a source record
- a temporary runtime override without explicit exit criteria
- a runtime with unknown deploy traceability being treated as governance-complete
- frontend inferring or guessing canonical runtime from observed behavior
- frontend independently switching from Railway to Edge or from Edge to Railway without a governance update

### 3.1 Split runtime prohibition

A frontend-facing API family must not remain long-term in any of these states:

- `GET` on Edge while `PATCH` remains on Railway without an explicit temporary override record
- list endpoints on one runtime while detail endpoints on another runtime without explicit family governance
- one frontend surface consuming both app-route and edge-route variants of the same family

### 3.2 Temporary override rule

If a temporary runtime override is used, all of the following are mandatory:

1. a source record exists
2. the temporary runtime is named explicitly
3. the canonical design source is still named explicitly
4. contract ownership is explicit
5. exit criteria are recorded

### 3.3 Traceability rule

If deploy target, deploy method, source path, or deployment trace is unknown, the runtime may still exist operationally, but it must not be described as governance-complete.

### 3.4 Frontend consumption rule

Frontend must not:

- guess canonical runtime
- treat a temporary override as the permanent source of truth
- switch to an alternate runtime because it “seems to work”
- infer ownership from payload shape alone

Frontend may only consume the runtime designated by:

- the contract doc
- the source record
- and the runtime decision record when one exists

## 4. Runtime Placement Decision Table

| Condition | Default runtime | Rule |
| --- | --- | --- |
| auth/session/context orchestration | Railway | must stay in Railway |
| workflow/business rule with multi-step permission or state transitions | Railway | must stay in Railway even if DB/RPC supports part of the logic |
| lightweight read-model shaping | Railway or Edge | allowed in either, but canonical owner must be explicitly designated |
| internal lookup/read-only substrate | DB / RPC / direct client | may stay below the frontend-facing API layer; should not automatically become product API |
| temporary proxy / migration bridge | Edge | allowed only with source record, contract continuity, and exit criteria |

### 4.1 Railway placement criteria

Place the API family in Railway when it:

- resolves auth/session
- depends on selected context or preview override
- shapes the canonical frontend response contract
- coordinates multiple reads/writes across entities
- performs workflow authorization checks

### 4.2 Edge placement criteria

Place the API family in Edge only when:

- Edge is intentionally designated as the canonical owner
- or Edge is explicitly serving as a temporary proxy

Edge is not acceptable simply because:

- it is easier to hotfix quickly
- it already exists somewhere else
- frontend has already started calling it

### 4.3 DB / RPC / direct client placement criteria

Keep logic in DB / RPC / direct client when it is:

- internal lookup
- pure data substrate
- reusable mutation kernel behind a Railway-owned contract
- not intended to be the primary frontend-facing contract owner

## 5. Definition Of Done For Frontend-Facing API Families

A frontend-facing API family is not complete unless all of the following exist:

1. contract doc
2. source record
3. runtime classification
4. deploy target
5. deploy method
6. deployment trace
7. temporary override details and exit criteria, if a temporary override exists

Any missing item above means:

- the API family may exist in runtime
- but it is not governance-complete
- and must not be treated as stable integration-ready surface

## 6. Current Runtime Inventory

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
| debug / observability related endpoints | Railway internal audit endpoint for LINE audit; raw access logging lives in DB; central error pool not yet implemented | [`app/api/integrations/line/audit/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/integrations/line/audit/route.ts), [`public.api_access_logs` migration](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/supabase/migrations/20260408101000_staging_beta_lock_security_setup.sql:48), [error events proposal](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/error-events-foundation-v1.md) | mixed: audit route exists, raw logs exist, central error pool is still proposal-only | Railway for internal audit surfaces; DB / RPC / direct client for raw storage | source unresolved for future error ingest, duplicated mapping logic, no unified error pipeline |

## 7. Recommended Runtime Policy v1

### What MUST stay in Railway

- any frontend-facing endpoint that resolves auth/session context
- any endpoint that depends on selected context, preview override, or membership gating
- any endpoint that assembles a canonical response contract across multiple tables
- any workflow mutation with multi-step authorization or state transitions

### What MAY live in Edge

- temporary runtime proxies during controlled migration
- narrow read-only surfaces intentionally designated as edge-owned
- transitional compatibility layers that preserve the canonical contract while canonical runtime is being repaired

Mandatory conditions:

- contract doc exists
- source record exists
- runtime classification is explicit
- deploy trace is explicit
- canonical owner is explicit

### What SHOULD NOT be wrapped as API

- raw internal logging tables such as `public.api_access_logs`
- helper RPC that only supports a Railway-owned contract
- internal lookup material that does not need a standalone frontend-facing contract

## 8. Immediate Reclassification Candidates

1. employee detail `GET`
2. employee detail family as a whole
3. leave requests family
4. leave approval actions family
5. debug / observability surfaces

## 9. Enforcement Summary

This rule prevents runtime sprawl by forcing one decision before frontend work starts:

- one frontend-facing API family
- one canonical runtime
- one contract owner
- one deploy trace

If a second runtime appears later, it must be recorded explicitly as a temporary override with exit criteria, or it is a governance violation.
