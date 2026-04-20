# Employee Detail Convergence Decision v1

Status: formal convergence decision

Purpose:

- define one long-term canonical interpretation for employee detail read and write behavior
- remove ambiguity across Railway app routes, temporary Edge runtime usage, and frontend adapter assumptions
- apply the same convergence discipline that was used successfully for leave family

This document is a decision document.
It does not itself change runtime behavior.

## 1. Current Split Summary

Current employee detail family is split at the runtime level:

- `GET /api/hr/employees/:id` has a documented temporary frontend-facing Edge runtime override
- `PATCH /api/hr/employees/:id` remains on the Railway app route as the canonical write runtime

Current split is not only about deploy target.
It also creates path-semantics drift and identity confusion:

- current `GET` supports both employee UUID and exact `employee_code`
- current `PATCH` supports employee UUID only
- frontend can currently pass a path token, but that token must not be treated as identity truth

This is the employee-detail version of the same governance problem leave family had:

- more than one effective runtime interpretation
- more than one path/lookup interpretation
- no single completed source-of-truth loop from auth -> scope -> runtime -> frontend usage

## 2. Canonical Target Decision

### 2.1 Canonical Read Endpoint

Long-term canonical read endpoint must be:

- `GET /api/hr/employees/:id`

Decision:

- the canonical source remains the Railway app route
- any Edge runtime serving employee detail read is temporary compatibility only
- frontend must treat the Railway route contract as the long-term canonical read surface

### 2.2 Canonical Write Endpoint

Long-term canonical write endpoint must be:

- `PATCH /api/hr/employees/:id`

Decision:

- write ownership remains on the Railway app route
- no second write family may be introduced
- no separate Edge write runtime should be treated as canonical unless governance is explicitly re-designated in a future decision document

### 2.3 Canonical Identity Resolution

Long-term canonical identity rule must be:

- authenticated user is the only canonical auth source
- frontend path input is only a lookup token, not identity truth
- employee identity truth must come from server-side resolution under authenticated access and scoped employee lookup

Direct rule:

- frontend must not treat `:id` or `employee_code` as the source of truth for authorization
- frontend may navigate by a path token, but server must decide whether that token resolves to a scoped employee row
- frontend must not send `id` or `employee_code` as an identity override mechanism outside the canonical path contract

For employee detail, this means:

- `GET` may accept a lookup token for retrieval
- `PATCH` must operate on the canonical employee UUID target resolved within scope
- authorization truth is never supplied by frontend path semantics alone

### 2.4 Canonical Scope Model

Long-term canonical scope model must be:

- selected context is the only app-layer scope source
- JWT-backed authenticated user context is the only auth source
- no employee detail flow should rely on frontend-provided org/company/branch/code as final truth

Decision:

- employee detail scope must resolve from selected context plus JWT
- frontend query params may exist only as temporary compatibility or explicit disambiguation, not as independent truth
- app-layer scope, route-level access checks, and runtime data access must converge on the same selected-context interpretation

In short:

- auth truth: JWT
- scope truth: selected context
- employee row truth: server-side scoped lookup

### 2.5 Temporary Runtime Override

Current decision:

- yes, a temporary runtime override exists for `GET /api/hr/employees/:id`
- current documented temporary runtime is Supabase Edge
- `PATCH /api/hr/employees/:id` does not currently have a temporary runtime override

Governance rule:

- the Edge runtime is temporary compatibility only
- it must not be treated as the permanent employee detail owner
- frontend must not infer that Edge becomes canonical simply because it is currently serving integration traffic

### 2.6 Direct Answers

#### Canonical read endpoint

- keep: `GET /api/hr/employees/:id` on Railway as the long-term canonical read endpoint

#### Canonical write endpoint

- keep: `PATCH /api/hr/employees/:id` on Railway as the long-term canonical write endpoint

#### Identity resolution

- frontend must not treat `id` or `employee_code` as identity truth
- identity truth belongs to authenticated user plus scoped server-side employee resolution

#### Scope model

- employee detail scope must come only from selected context plus JWT

#### Temporary runtime override

- yes, `GET` currently has a temporary Edge override
- no, that override is not the long-term canonical owner

## 3. Decision Principles

### 3.1 What May Be Preserved Temporarily

These realities may remain temporarily during convergence:

- Edge serving `GET /api/hr/employees/:id` for compatibility
- current `GET` support for UUID or exact `employee_code`
- frontend adapter logic that still bridges current read/write path mismatch during migration

### 3.2 What Must Be Eliminated

These behaviors must not remain as long-term policy:

- permanent split runtime where read lives on Edge and write lives on Railway without closure
- frontend treating path token semantics as authorization truth
- frontend relying on `employee_code` or arbitrary path values as the durable write target truth
- any scope interpretation that bypasses selected context plus JWT as the authoritative model

### 3.3 Temporary Compatibility Only

The following are temporary compatibility only:

- Supabase Edge as the frontend-facing runtime for employee detail `GET`
- any frontend adapter behavior that assumes `GET` and `PATCH` have different long-term runtime owners
- any UI flow that preserves employee detail behavior only by remembering code-like lookup tokens instead of canonical scoped employee identity

## 4. Exit Criteria

Employee detail convergence is complete only when all of the following are true:

1. `GET /api/hr/employees/:id` is served from the canonical Railway runtime, not a temporary Edge override
2. `PATCH /api/hr/employees/:id` remains on the same Railway-owned family
3. frontend employee detail traffic no longer depends on the temporary Edge runtime
4. frontend uses canonical employee UUID for write follow-up after read, rather than treating `employee_code` as write truth
5. scope behavior is governed by selected context plus JWT, without frontend-provided identifiers acting as final truth
6. source records are updated so employee detail is documented as one coherent single-runtime family

## 5. Recommended Convergence Path

Recommended path, following the leave pattern:

### Phase 1

- keep the temporary `GET` override explicitly documented
- declare Railway as the canonical read/write owner in architecture docs
- make the identity and scope rules explicit before runtime switching

### Phase 2

- align frontend employee detail usage so write follow-up uses canonical employee UUID resolved from the read response
- reduce dependence on query/path-based assumptions that behave like independent truth

### Phase 3

- retire the temporary Edge override for `GET`
- return employee detail fully to one Railway runtime family
- close the source-governance loop so employee detail is no longer documented as split runtime

## 6. Non-Goals

This decision does not cover:

- leave family
- attendance
- payroll
- recruiting
- employee list redesign
- schema changes
- global Edge / Railway platform refactor
