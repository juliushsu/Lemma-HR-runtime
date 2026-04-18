# API Contract Documentation System v1

## Purpose

This folder is the single source of truth for runtime API contracts in Lemma HR+.

Goals:

- every API has one authoritative contract document
- frontend adapters do not guess response shape
- API vs adapter vs UI issues can be debugged from the contract first
- code changes and contract changes ship together

## Authority Rules

Priority order:

1. `docs/api-contracts/*.md`
2. route runtime behavior in `app/api/**`
3. older handoff / proposal / mapping docs

If an older proposal or handoff doc conflicts with a file in this folder, this folder wins.

## Naming Rules

One file per method + endpoint family + schema version.

Examples:

- `hr.employees.get.v1.md`
- `hr.employees.patch.v1.md`
- `hr.leave.requests.create.v1.md`
- `hr.org-chart.get.v1.md`

Rules:

- use domain-first naming
- use lowercase with dots
- encode the HTTP action in the filename
- bump the filename version when the contract meaningfully changes

## Required Sections

Every contract file must include all of the following:

1. `Endpoint Metadata`
2. `Request Contract`
3. `Response Contract`
4. `UI Consumption Rules`
5. `Error Matrix`
6. `Smoke Examples`
7. `Debug Playbook`

## Contract Writing Rules

- document current runtime behavior, not the desired future state
- include the actual response envelope and shape
- state whether the payload is nested or flat
- distinguish guaranteed fields from optional nullable fields
- explicitly list currently missing but expected fields when relevant
- mark derived fields that are display-only and not writable
- mark unsupported request fields that are ignored
- state whether a write response can be used as a view model
- state whether the UI must refetch a GET read model after write

## Definition Of Done

An API change is not done unless:

1. its contract file exists
2. the contract reflects runtime behavior
3. request and response examples are updated
4. the `Debug Playbook` is updated when debugging behavior changes

## Change Rules

- no contract document: not done
- API behavior changed: update the contract in the same change
- response shape changed: update `schema_version`
- do not ship code-only shape changes
- do not maintain multiple truth-sources for the same route

## Suggested Review Flow

When debugging:

1. confirm the contract file for the route
2. confirm the live response matches the contract
3. confirm the frontend adapter matches the contract
4. only then inspect UI rendering logic
