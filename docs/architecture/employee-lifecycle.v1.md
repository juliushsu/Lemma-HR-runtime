# Employee Lifecycle v1

## Purpose

Define the Phase 1 canonical lifecycle model for:

- `candidate`
- `onboarding`
- `employee`

This document is a staging-only additive governance decision. It does not retire existing legacy onboarding tables in this round.

## Canonical Phase 1 Model

Phase 1 uses the following canonical tables:

- `public.candidates`
- `public.onboarding_profiles`
- `public.onboarding_documents`
- `public.onboarding_signatures`
- `public.employees` (reused, aligned with a new `source_onboarding_profile_id`)

## Core Rules

1. `candidate` is not the same domain object as `employee`.
2. `onboarding` is the required middle layer between candidate and employee.
3. `employees` must be materialized from `onboarding_profiles`.
4. `employees.source_onboarding_profile_id` is the canonical source link for Phase 1.
5. Once an employee has an onboarding source, that source is immutable.

## Why `employees` Is Reused

The repo already has a canonical `employees` table with:

- org/company/branch/environment scope
- department / position / manager links
- core employment fields
- basic RLS helpers

Phase 1 does not replace `employees`. It adds lifecycle source linkage so the employee master stays canonical without inventing a parallel employee table.

## Minimal Status Model

To avoid enum explosion, Phase 1 keeps a small status surface:

- `candidates.candidate_status`
  - `candidate`
  - `screening`
  - `offered`
  - `withdrawn`
  - `converted`
- `onboarding_profiles.onboarding_status`
  - `draft`
  - `invited`
  - `submitted`
  - `approved`
  - `converted`
  - `cancelled`

## Document And Signature Scope

`onboarding_documents` and `onboarding_signatures` are intentionally generic in Phase 1:

- no OCR pipeline
- no workflow engine
- no contract orchestration
- no public-portal RLS split

They exist only to establish canonical onboarding record types and auditable storage references.

## RLS

Phase 1 lifecycle tables use basic scope-based RLS:

- read: `can_read_scope(...)`
- write: `can_write_scope(...)`

This is intentionally minimal. Invitee/self-service onboarding access remains outside this round.

## Existing Schema Overlap

The repo already contains legacy onboarding tables such as:

- `employee_onboarding_invitations`
- `employee_onboarding_intake`
- `employee_onboarding_documents`
- `employee_onboarding_signatures`

Phase 1 does not delete or migrate them yet. They remain legacy runtime tables until a later convergence round.

## Non-goals

This round does not do:

- candidate pipeline UX
- onboarding portal
- provisioning
- payroll setup
- attendance setup
- employee detail API redesign
- production rollout
