# System Overview v1

## Purpose

Lemma HR+ currently operates as a single collaboration repository that contains:

- a Next.js application layer
- API route handlers used as backend endpoints
- Supabase schema and RLS logic
- shared contracts for frontend mapping
- runbooks and domain documentation

This document fixes the system boundaries so different collaborators can work from the same model.

## Primary Layers

### Application Layer

- Path: `app/`
- Owns HTTP routes, adapter logic, request shaping, and response envelopes
- Key backend routes currently live under `app/api/`

### Data Layer

- Path: `supabase/migrations/`
- Owns database schema, RLS, helper functions, and environment access rules

### Seed Layer

- Path: `supabase/seeds/`
- Owns bootstrap data, narrative demo data, and staging validation data
- Seeds are now separated into `base`, `demo`, and `staging`

### Contract Layer

- Path: `contracts/`
- Owns shared DTO definitions for frontend and backend alignment

### Operational Documentation

- Path: `DOCS/`
- Owns architecture decisions, runbooks, product status, and smoke references

## Collaboration Boundaries

- Readdy should consume contracts and product docs, not infer backend semantics from incidental payload order.
- Codex should update contracts and runbooks when changing shared behavior.
- Testing partners should use runbooks and seed registry instead of ad hoc seed execution.
- Product decisions should land in docs before expanding runtime behavior across environments.

## Current Architecture Constraint

The current auth/session model still tends to infer runtime context from the first available membership. That is acceptable for single-context users, but not for the future `demo + staging-write` dual-access model. The next governance phase should introduce explicit selected context handling.

## Canonical Environment Model

- `production`: live business data
- `demo`: read-only narrative experience
- `sandbox` or `staging-write`: writable internal validation environment
- `seed`: setup-oriented support records

See `DOCS/architecture/environment-governance-v1.md` for the operational rules.

## Phase 2 Design References

- `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md`
- `contracts/auth.me.v2.md`
- `contracts/auth.session.context.v1.md`
