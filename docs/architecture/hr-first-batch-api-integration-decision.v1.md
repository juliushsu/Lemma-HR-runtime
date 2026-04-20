# HR First Batch API Integration Decision v1

## Purpose

This document formally decides the first batch of HR API integration modules based on:

- [employee-lifecycle.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/employee-lifecycle.v1.md)
- [employee-change-governance.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/employee-change-governance.v1.md)
- [attendance-correction.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/attendance-correction.v1.md)
- [hr-ui-schema-alignment.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/hr-ui-schema-alignment.v1.md)
- [lemma-runtime-layering-v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/lemma-runtime-layering-v1.md)

This is an API integration decision only.

It does not:

- create API routes
- replace runtime source records
- perform schema migration rollout

## Decision Summary

The first batch modules are:

1. self change requests
2. self attendance correction
3. HR attendance review
4. self profile read + request-based profile edit

These are selected because they already have the clearest Phase 1 governance direction, the lowest schema ambiguity, and the best fit for a single Railway-owned API family.

## 1. First Batch Modules

### A. Self Change Requests

Why it is in the first batch:

- it is already `fully aligned` in the UI/schema alignment review
- the request-vs-audit governance line is explicit
- it does not depend on legacy onboarding runtime
- it fits a clean Railway-owned family with DB tables beneath it

### B. Self Attendance Correction

Why it is in the first batch:

- it is already `fully aligned`
- append-only raw event rule is explicit
- self submit and HR review path are both clear
- it is a natural governance-first API slice with bounded surface area

### C. HR Attendance Review

Why it is in the first batch:

- it is the operational counterpart to self attendance correction
- review action can stay within one family centered on `attendance_corrections`
- it is partially aligned today, but the canonical review direction is already clear enough to begin

### D. Self Profile Read + Request-Based Profile Edit

Why it is in the first batch:

- read truth is already anchored on `employees`
- write direction is already governed by `employee_change_requests`
- this gives the UI a safe path without reopening direct self-write ambiguity

## 2. Recommended Order

Recommended implementation order:

1. self change requests
2. self attendance correction
3. HR attendance review
4. self profile read + request-based profile edit

Reasoning:

- `self change requests` is the cleanest first slice because the governance model is fully aligned and does not require legacy runtime untangling
- `self attendance correction` comes next because it is also fully aligned, but depends on referenced attendance event context
- `HR attendance review` should follow once correction submission shape exists
- `self profile` should come after the request pattern is proven, so profile write can reuse the same governance conventions instead of inventing a separate edit model

## 3. Runtime Decision

### Runtime Table

| Module | Runtime | Reason |
| --- | --- | --- |
| self change requests | `Railway` | selected context, auth/session resolution, self-vs-HR permission checks, and contract shaping all belong in Railway |
| self attendance correction | `Railway` | actor resolution, selected context, and request orchestration are workflow concerns and must stay in Railway |
| HR attendance review | `Railway` | approval/rejection workflow and context-aware review decisions are multi-step business rules and must stay in Railway |
| self profile read + request-based profile edit | `Railway` | read shaping, selected context, and request-governed write orchestration should stay in one Railway family |

### Runtime Rule

For the first batch:

- canonical frontend-facing runtime: `Railway`
- allowed internal substrate: `DB / RPC / direct Supabase client`
- not selected: `Supabase Edge`

Why Edge is not chosen:

- these modules depend on auth/session/context orchestration
- these modules require selected-context interpretation
- these modules are not temporary proxy candidates

Why DB/RPC is not chosen as frontend runtime:

- DB/RPC may remain the data substrate
- but frontend-facing contract ownership must remain in Railway under current runtime governance

## 4. Required Contracts Before Integration

### A. Self Change Requests

Still required:

- API contract doc for the list/create family
- source record for the chosen route family
- runtime decision record if the module family spans multiple route endpoints
- canonical error vocabulary for self invalid scope / unauthorized resolution / missing employee binding

Suggested family shape:

- `GET /api/hr/me/change-requests`
- `POST /api/hr/me/change-requests`

### B. Self Attendance Correction

Still required:

- API contract doc for correction list/create
- source record for the module family
- runtime decision record tying correction read/write to Railway
- canonical error vocabulary for missing employee binding / invalid original event / forbidden scope

Suggested family shape:

- `GET /api/hr/me/attendance-corrections`
- `POST /api/hr/me/attendance-corrections`

### C. HR Attendance Review

Still required:

- API contract doc for HR review list/detail/action surfaces
- source record for the canonical route family
- explicit runtime decision that review stays on Railway even if attendance data substrate remains in DB
- canonical action contract for approve / reject

Suggested family shape:

- `GET /api/hr/attendance-corrections`
- `GET /api/hr/attendance-corrections/:id`
- `POST /api/hr/attendance-corrections/:id/approve`
- `POST /api/hr/attendance-corrections/:id/reject`

### D. Self Profile Read + Request-Based Profile Edit

Still required:

- API contract doc for self profile read
- API contract doc for request-based self profile change submission
- source record for the route family
- explicit field-governance note for which profile fields are editable through requests

Suggested family shape:

- `GET /api/hr/me/profile`
- `POST /api/hr/me/profile-change-requests`

## 5. Non-goals

The following are explicitly not in the first batch:

- payroll
- recruiting AI pipeline
- self documents full runtime
- attendance summary analytics
- onboarding invitation / profile / documents / signature integration
- candidate pipeline
- attendance device ingestion
- shift policy engine
- provisioning workflow
- post-hire full employee document management

Reason:

- either the schema direction is still incomplete
- or runtime overlap is still too high
- or the module is outside Phase 1 governance scope

## 6. Modules Deferred From First Batch

### Onboarding Invitation / Profile / Documents / Signature

Deferred because:

- legacy onboarding runtime overlap remains
- no single canonical API family has been declared yet
- not safe for first-batch frontend integration

### Self Attendance

Deferred as a standalone first-batch surface because:

- canonical target is clear
- but current runtime still overlaps with legacy attendance read surfaces
- correction flows should land before general attendance history integration

### Self Documents Full Runtime

Deferred because:

- Phase 1 only establishes onboarding documents
- it does not yet define a canonical post-hire self-documents domain

## 7. Recommended First Actual Implementation Target

The single recommended first actual implementation target is:

- `self change requests`

Why this is first:

- it is the most fully aligned module in both schema and governance terms
- it has the least legacy runtime coupling
- it creates a reusable pattern for self-authenticated request submission
- it gives the team a clean model for future self profile edit integration

## 8. Practical Rule

For the HR first batch:

- choose modules with the clearest governance before modules with the broadest UI scope
- keep frontend-facing ownership in Railway
- require contract doc + source record before implementation starts
- avoid onboarding and full attendance-history expansion until runtime convergence is stronger
