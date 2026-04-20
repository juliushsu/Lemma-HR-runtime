# Employee Change Governance v1

## Purpose

Define the Phase 1 canonical governance model for employee master-data changes.

This round introduces a minimal two-layer model:

- request layer: `employee_change_requests`
- audit layer: `employee_change_logs`

## Core Decision

Employee master changes must not be modeled as direct silent updates.

Phase 1 separates:

1. the request to change a field
2. the audited record of what actually changed

That means:

- `employee_change_requests` is not the employee master itself
- `employee_change_logs` is append-only audit evidence
- approved change handling can be implemented later without replacing this schema

## Canonical Tables

- `public.employee_change_requests`
- `public.employee_change_logs`

## Minimal Status And Source Model

To stay Phase 1 minimal:

- request status:
  - `pending`
  - `approved`
  - `rejected`
- log source:
  - `self`
  - `hr`
  - `system`

No workflow-engine states are added in this round.

## Required Governance Rules

1. Change request does not equal direct employee update.
2. Every approved change must be representable in `employee_change_logs`.
3. Logs are append-only.
4. Self-service requests may exist, but approval remains scope-governed.

## RLS

Phase 1 uses basic scope-and-self rules:

- request read:
  - `can_read_scope(...)`
  - or `employee_id = current_jwt_employee_id()`
- request insert:
  - scoped HR writers
  - or self-created pending requests
- request update:
  - scoped HR writers only
- log read:
  - scoped readers
  - or self employee
- log insert:
  - scoped HR writers
  - or self-authored log rows with `source = 'self'`

No delete policies are added for the audit tables.

## Why This Is Phase 1 Only

This schema intentionally stops before:

- diff engines
- multi-step approvals
- field-level approval matrices
- notification workflow
- automatic writeback into `employees`

Those can be layered later without changing the core request-vs-audit separation.

## Non-goals

This round does not do:

- employee UI forms
- API routes
- auto-approval logic
- provisioning flags
- payroll or attendance side-effects
