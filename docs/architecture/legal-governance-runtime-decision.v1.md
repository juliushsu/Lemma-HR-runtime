# Legal Governance Runtime Decision v1

## Purpose

Define the canonical runtime ownership for the AI-assisted legal governance layer.

This decision covers:

- system legal governance settings
- legal update retrieval
- governance comparison retrieval
- reserved adoption actions
- reserved document / policy analysis family

## Decision

Canonical frontend-facing runtime for the legal governance layer is:

- `Railway`

## Why Railway

The legal governance layer depends on:

1. authenticated JWT actor resolution
2. selected context resolution for company-scoped governance views
3. system-level role enforcement for platform-owned settings
4. company-level role enforcement for governance result access
5. AI result orchestration
6. policy diff aggregation across multiple business domains
7. safe separation between advisory AI output and human adoption actions

These are application orchestration concerns and should remain in Railway.

## Why Not Supabase Edge

This layer should not be owned by Supabase Edge because:

- model-control settings are not simple edge-proxy concerns
- actor / role / scope enforcement must stay aligned with app runtime governance
- governance checks aggregate more than one domain family
- adoption actions require audit-oriented application semantics

Edge may be used later for narrow internal helper workflows, but it should not own the public contract.

## Why Not DB / RPC As Frontend Runtime

`DB / RPC / direct client` may become an internal substrate later, but should not own the frontend contract.

Reason:

- legal-governance comparison is not raw table access
- advisory result shaping, severity labeling, and action semantics are app-layer concerns
- selected context and system-level ownership should not split across frontend and database policy

## Ownership Decision

### System-Level Managed

Only platform / system governance may control:

- legal model selection
- fallback model
- provider / key binding
- auto update schedule
- global legal scanning policy
- base legal knowledge refresh

### Customer-Level Accessible

Customers may access:

- legal update results relevant to their company
- governance checks for their own policies and documents
- document / policy analysis outcomes
- adoption actions and warning acknowledgement

Customers may not directly modify:

- active legal model
- fallback model
- provider configuration
- global scan policy

## Scope Decision

The legal governance layer has two scope planes.

### System plane

For `/api/system/legal-governance/settings`:

- scope is platform / system-level
- selected customer context is not the authority for write permission

### Customer plane

For `/api/legal/*`:

- scope source is selected context + JWT
- company-level legal governance views are constrained to selected company scope

## Adoption Decision

Adoption actions must remain human-triggered.

Phase 1 decision:

- AI may suggest
- human must adopt, dismiss, or acknowledge
- automatic direct policy overwrite is prohibited

This rule applies even when a governance check is marked `critical`.

## Analysis Family Decision

Document / policy analysis is allowed as a governed family, but must still be:

- advisory
- explainable
- reviewable

It must not impersonate:

- a final legal opinion
- a formal binding legal notice
- an autonomous policy executor

## Recommended Implementation Order

If implementation starts next round:

1. `GET /api/legal/governance-checks`
2. `GET /api/legal/governance-checks/:id`
3. `GET /api/legal/updates`
4. `GET /api/system/legal-governance/settings`
5. `POST /api/legal/governance-checks/:id/acknowledge-warning`

Reason:

- governance checks are the first customer-visible value surface
- updates are useful but secondary to actionable comparison
- system settings should remain tightly gated and can be added after read surfaces stabilize

## Phase 1 Non-goals

This runtime decision does not include:

- autonomous legal update execution
- customer-controlled model switching
- direct policy mutation
- insurer pricing / underwriting integration
- full country-by-country law engine
- full document clause generation
- uncontrolled real-time legal crawling
