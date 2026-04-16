# Module Status v1

## Purpose

This is the shared high-level status sheet for product, frontend, backend, and testing alignment. It is intentionally lightweight and should be updated as modules move from contract-first to runtime-stable.

## Current Modules

| Module | Status | Notes |
| --- | --- | --- |
| Auth / Session | Active | `auth.me.v1` exists; selected context still needs explicit contract and runtime handling |
| Portal | Active on staging | DTO alignment and narrative seed work are underway |
| HR Employee Core | Active | Employee, org chart, departments, attendance, onboarding work present |
| Attendance Integration | Active on staging | Phase 1 schema and APIs are present |
| LC+ | Active | Legal cases and document flows exist with demo seeds |
| Environment Switch | Planned | Needs selected context API and frontend switcher contract |
| Demo Reset | Planned | Should be maintenance-only, not general smoke flow |

## Governance Status

| Area | Status | Notes |
| --- | --- | --- |
| Repo structure baseline | In progress | This governance pass creates the shared baseline |
| Seed layering | In progress | Split into `base`, `demo`, `staging` |
| Contract discipline | In progress | `auth.me.v2` added as forward-looking baseline |
| Demo protection | Planned | Needs RLS/runtime guardrails in phase 2 |

## Definition of Stable Enough for Cross-Team Work

A module is stable enough for shared collaboration when:

- the DTO/contract is documented
- the target environment is explicit
- the seed dependency is known
- the write/read risk is documented
