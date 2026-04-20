# HR UI Schema Alignment v1

## Purpose

This document aligns the current HR UI skeleton targets with the Phase 1 schema and governance baseline.

It is a planning and gap-analysis document only.

It does not:

- change migration ownership
- define new APIs
- change runtime canonical source

## Scope

This alignment review covers:

- onboarding invitation / profile / documents / signature
- self profile
- self documents
- self attendance
- self change requests
- self attendance correction
- HR attendance review

## Reading Basis

This document is based on:

- [employee-lifecycle.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/employee-lifecycle.v1.md)
- [employee-change-governance.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/employee-change-governance.v1.md)
- [attendance-correction.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/attendance-correction.v1.md)
- [employee-lifecycle-schema.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/employee-lifecycle-schema.v1.md)
- [employee-change-governance-schema.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/employee-change-governance-schema.v1.md)
- [attendance-correction-schema.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/attendance-correction-schema.v1.md)

The repo currently has only partial backend runtime for these HR domains, and does not yet contain a fully implemented self-service UI set for all modules below. As a result, the statuses here mean schema-to-skeleton readiness, not production-ready feature completeness.

## Alignment Table

| Module | Schema Tables | Alignment | Canonical Read/Write Direction | First-Batch API Integration | Current Biggest Gap |
| --- | --- | --- | --- | --- | --- |
| Onboarding invitation / profile / documents / signature | `candidates`, `onboarding_profiles`, `onboarding_documents`, `onboarding_signatures`, legacy `employee_onboarding_*` overlap | `partially aligned` | Write direction is clear for Phase 1 canonical lifecycle tables, but read/write runtime is still split with legacy onboarding tables | `no` | Legacy onboarding runtime still exists under `employee_onboarding_*`, while Phase 1 canonical tables are additive only and not yet tied to a single API family |
| Self profile | `employees`, `employee_change_requests`, `employee_change_logs` | `partially aligned` | Canonical read anchor is `employees`; canonical write direction should be request-driven through `employee_change_requests`, not direct self patching | `yes` | Self profile read can anchor to `employees`, but the self-edit governance path is not yet implemented as a canonical request-based API |
| Self documents | `onboarding_documents`, legacy `employee_onboarding_documents` | `missing` | No stable canonical self documents read/write direction yet | `no` | Phase 1 documents are onboarding-scoped, not employee-lifecycle post-hire document management; self-document ownership model is not yet defined |
| Self attendance | `attendance_events`, legacy `attendance_logs`, `employee_attendance_profiles`, `attendance_policies` | `partially aligned` | Canonical long-term read direction should move to `attendance_events`; current runtime still mainly points to legacy attendance surfaces | `yes` | Existing runtime and feature surfaces are still based on `attendance_logs` style MVP data, while Phase 1 canonical append-only events are additive only |
| Self change requests | `employee_change_requests`, `employee_change_logs` | `fully aligned` | Read/write direction is clear: self creates pending requests, HR resolves, audit remains append-only in logs | `yes` | Main gap is API implementation, not schema direction |
| Self attendance correction | `attendance_corrections`, `attendance_events` | `fully aligned` | Read/write direction is clear: self submits correction requests, original event remains append-only, HR approves/rejects | `yes` | Main gap is API implementation and selected-context actor resolution, not schema ambiguity |
| HR attendance review | `attendance_corrections`, `attendance_events`, legacy `attendance_logs`, legacy `attendance_adjustments` | `partially aligned` | Canonical review direction should center on `attendance_corrections` plus referenced `attendance_events` | `yes` | HR review runtime is still likely to encounter legacy `attendance_logs` / `attendance_adjustments` behavior until canonical review APIs are introduced |

## Module Notes

### 1. Onboarding Invitation / Profile / Documents / Signature

Schema tables:

- canonical Phase 1:
  - `candidates`
  - `onboarding_profiles`
  - `onboarding_documents`
  - `onboarding_signatures`
- legacy overlap:
  - `employee_onboarding_invitations`
  - `employee_onboarding_intake`
  - `employee_onboarding_documents`
  - `employee_onboarding_signatures`

Status:

- `partially aligned`

Reason:

- The lifecycle decision is now clear.
- The schema direction is canonical.
- But the repo still contains a legacy onboarding runtime family, so the UI skeleton does not yet have one unambiguous API family to consume.

Canonical read/write direction:

- long-term write: canonical lifecycle tables
- long-term read: canonical lifecycle tables
- temporary compatibility: legacy onboarding family remains present

First-batch API integration:

- `no`

Largest gap:

- route/runtime convergence has not happened yet, so onboarding is not a good first integration target even though the schema baseline exists

### 2. Self Profile

Schema tables:

- `employees`
- `employee_change_requests`
- `employee_change_logs`

Status:

- `partially aligned`

Reason:

- Read truth is straightforward through `employees`.
- Write governance direction is also clear: self-change should become a request, not a direct master update.
- What is still missing is the canonical request API family and field-by-field policy implementation.

Canonical read/write direction:

- read: `employees`
- write: `employee_change_requests`
- audit: `employee_change_logs`

First-batch API integration:

- `yes`

Largest gap:

- the self profile edit path is not yet exposed as a request-governed API slice

### 3. Self Documents

Schema tables:

- `onboarding_documents`
- legacy `employee_onboarding_documents`

Status:

- `missing`

Reason:

- The available documents schema is still onboarding-oriented.
- There is no Phase 1 post-hire self-document canonical model yet.

Canonical read/write direction:

- not yet stable

First-batch API integration:

- `no`

Largest gap:

- no canonical employee-owned document domain after onboarding completion

### 4. Self Attendance

Schema tables:

- canonical:
  - `attendance_events`
- existing runtime support tables:
  - `employee_attendance_profiles`
  - `attendance_policies`
- legacy overlap:
  - `attendance_logs`

Status:

- `partially aligned`

Reason:

- The Phase 1 schema clearly establishes append-only events as the canonical target.
- But current repo surfaces and integrations still point heavily at the older attendance MVP shape.

Canonical read/write direction:

- long-term read/write: `attendance_events`
- temporary runtime overlap: `attendance_logs`

First-batch API integration:

- `yes`

Largest gap:

- canonical attendance event APIs do not yet exist, while legacy attendance endpoints still shape current behavior

### 5. Self Change Requests

Schema tables:

- `employee_change_requests`
- `employee_change_logs`

Status:

- `fully aligned`

Reason:

- The schema baseline, governance model, and write direction all agree.
- This is one of the cleanest Phase 1 modules for API onboarding.

Canonical read/write direction:

- read: self request list + self change audit
- write: self inserts pending `employee_change_requests`
- resolution: HR updates request status and appends logs

First-batch API integration:

- `yes`

Largest gap:

- API and response contracts are not implemented yet

### 6. Self Attendance Correction

Schema tables:

- `attendance_corrections`
- `attendance_events`

Status:

- `fully aligned`

Reason:

- The governance rule is clear.
- The append-only rule is clear.
- The self submit plus HR review lifecycle is clear.

Canonical read/write direction:

- read: self correction history + referenced attendance context
- write: self inserts pending correction request
- resolution: HR updates correction status

First-batch API integration:

- `yes`

Largest gap:

- API implementation and actor resolution rules are still missing

### 7. HR Attendance Review

Schema tables:

- `attendance_corrections`
- `attendance_events`
- legacy overlap:
  - `attendance_logs`
  - `attendance_adjustments`

Status:

- `partially aligned`

Reason:

- The canonical review model is now clear in schema terms.
- But runtime overlap with legacy attendance tables still exists.

Canonical read/write direction:

- read: HR reads `attendance_corrections` and related `attendance_events`
- write: HR resolves `attendance_corrections`

First-batch API integration:

- `yes`

Largest gap:

- legacy attendance review patterns are still present, so runtime convergence must happen before UI should assume only one review data source

## First-Batch API Integration Recommendation

The best first-batch API integration candidates are:

1. self change requests
2. self attendance correction
3. self profile read + request-based profile edits
4. HR attendance review

These are the strongest candidates because the schema and governance direction are already clear, even though runtime APIs are not implemented yet.

## Defer Recommendation

The following should not be first-batch API integrations:

1. onboarding invitation / profile / documents / signature
2. self documents

Reason:

- onboarding still has legacy-vs-canonical runtime overlap
- self documents does not yet have a strong post-hire canonical schema target

## Practical Rule

For HR UI integration planning:

- if schema direction is clear and runtime is not yet canonical, mark the module `partially aligned`
- if schema and governance are both clear and no major domain ambiguity remains, it may enter first-batch API integration
- if the domain still lacks a stable canonical read/write direction, mark it `missing` and keep it out of the first batch
