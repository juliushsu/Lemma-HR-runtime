# Environment Topology CTO Brief v1

## Purpose

Clarify the current Lemma environment topology across app semantics, membership/data semantics, and Railway deployment reality so product/UI language can stop implying a production state that does not yet exist as a complete backend deployment.

## Executive Summary

Lemma is currently operating as a staging-first system with partial legacy production semantics still visible in contracts, payload defaults, and UI language.

The mismatch is:

- Railway reality is staging-first
- data model supports multiple environment types, including future production
- selected-context rollout is explicitly staging-first
- some app/runtime labels still collapse non-demo, non-sandbox states into `production` / `production_live`

This means Lemma does not yet have a clean end-to-end production topology, even though some product surfaces still imply one.

## Topology By Layer

### 1) App Layer Environment

Current state:

- Runtime gating is staging-aware:
  - `isStagingRuntime()` checks `APP_ENV`, `NEXT_PUBLIC_APP_ENV`, `DEPLOY_TARGET`
  - selected context switching is enabled only in staging
  - debug headers are emitted only in staging
  - middleware beta lock protects staging APIs
- App metadata already describes the service as staging backend

Current mismatch:

- selected-context fallback still defaults unresolved context to `production`
- access-mode derivation treats any non-demo / non-sandbox context as `production_live`
- `GET /api/me` still returns `auth.me.v1` outside staging, so the architecture is intentionally asymmetric

Interpretation:

- `staging` is a real runtime concept
- `production` at app layer is partly a future semantic bucket, not a verified full deployment state

### 2) Membership / Data Environment

Current state:

- canonical environment values exist in data/contracts:
  - `production`
  - `demo`
  - `sandbox`
  - `seed`
- docs already define:
  - `demo` = protected narrative environment
  - `staging-write` / `sandbox` = writable internal validation environment
  - `production` = live customer environment
- seed registry is already split into `base`, `demo`, `staging`
- demo and staging are governed as separate operational layers

Current mismatch:

- data model supports `production`, but repo evidence does not show a complete real production backend topology in operation
- some older user / membership examples still use `production` as the default baseline even in staging-first workstreams

Interpretation:

- membership/data layer has a forward-compatible environment model
- `demo` and `sandbox` are operationally real
- `production` is currently schema-valid and semantically defined, but not yet proven as a complete live environment in this repo's operational model

### 3) Railway Deployment Environment

Confirmed real state:

- staging environment exists
- staging has `lemma-backend-staging` service

Confirmed missing state:

- no corresponding complete backend service is present in Railway production environment

Interpretation:

- Railway deployment reality is staging-first
- Railway production is currently a product/platform semantic placeholder, not a complete backend environment

## Real vs Semantic Inventory

### Real, operationally present now

- staging runtime gating
- staging backend service on Railway
- staging-only context switching
- staging beta lock
- sandbox / staging-write data and seeds
- demo data layer and demo reset governance

### Defined in docs/contracts, but not yet complete as end-to-end reality

- full live production topology
- production-safe selected-context rollout
- production backend parity in Railway
- production-grade operational guardrails and runbooks

### Mostly semantic / label debt right now

- product or UI use of `Production` when it points to no complete Railway production backend
- fallback defaults that map unspecified state to `production`
- `production_live` label being used as a catch-all for "not demo and not sandbox"

## CTO Decision Answers

### Should Lemma now be formally defined as staging-first?

Yes.

This is the most accurate current definition because:

- Railway backend reality is staging-first
- selected-context rollout is explicitly staging-first
- QA, smoke, mutation, and validation flows are all documented to target staging-write
- production does not yet exist as a complete backend deployment topology

Recommended working statement:

> Lemma is currently a staging-first system with protected demo data and a future reserved production tier.

### Should the UI `Production` badge be downgraded, hidden, or renamed?

Recommended: rename first, not hide.

Best temporary replacement:

- `Live model` should not be used
- `Production` should not be used
- prefer `Default`, `Primary`, or `Reserved`
- if the badge refers to current writable workspace, prefer `Staging`
- if the badge refers to org policy, prefer `Demo`, `Staging`, or `Read-only Demo`

Reason:

- hiding the badge removes confusion only superficially
- renaming makes the topology truthful and teaches the correct operating model
- keeping a false `Production` label creates the highest executive and operator confusion

Recommended temporary rule:

- never show `Production` unless there is an actual Railway production backend plus production-bound org/data policy behind it

### If a true production environment is needed later, what minimum infrastructure is required?

Minimum production foundation:

1. Railway
   - dedicated production backend service
   - dedicated production environment variables and secret set
   - production domain / routing
   - deploy promotion or release policy distinct from staging

2. Data / policy
   - dedicated production org and company records
   - explicit `organizations.access_mode = production_live`
   - production-safe RLS / write helpers validated against selected context
   - no demo/test users or sandbox shortcuts in production scope

3. App / API contract
   - clear production runtime detection
   - production `auth.me` behavior formally defined, not just "staging differs"
   - removal of ambiguous fallback-to-production semantics
   - UI environment labels driven by canonical backend policy

4. Operations
   - production deploy runbook
   - rollback runbook
   - incident / smoke / health-check checklist
   - seed prohibition or tightly controlled bootstrap-only procedure for production

## Suggested Topology Diagram

```text
Lemma Environment Topology (Current)

[App Layer]
  Next.js app + API routes
    |- staging runtime detection: REAL
    |- staging-only context switch: REAL
    |- some production fallback labels: SEMANTIC / LEGACY

[Membership / Data Layer]
  Supabase schema + memberships + org/company policy
    |- demo environment: REAL
    |- sandbox / staging-write environment: REAL
    |- production enum / contract meaning: DEFINED
    |- full live production operation: NOT YET REAL

[Railway Deployment Layer]
  staging environment
    |- lemma-backend-staging: REAL

  production environment
    |- complete backend service: NOT PRESENT

Conclusion:
  Runtime reality = staging-first
  Current mismatch = app/UI still expose partial production semantics
```

## Decision Recommendation

- Formally declare Lemma as `staging-first`
- Treat `demo` as a separate protected narrative environment
- Remove temporary UI claims that imply a real production backend exists today
- Reserve `production` for the future state that only becomes visible after infrastructure and policy parity exist

## Suggested Fix Order

1. Documentation truth alignment
   - publish current topology and terminology
   - define what is real vs reserved

2. UI terminology correction
   - downgrade or rename `Production` labels
   - map badges to `access_mode` / actual deployment reality

3. Backend semantic cleanup
   - stop using `production` as the generic fallback for unresolved context
   - distinguish `reserved production semantic` from `actual production deployment`

4. Production foundation
   - add real Railway production backend and deployment runbooks
   - then enable production labels in UI

## Suggested Docs To Add Or Update

Add:

- `docs/architecture/environment-topology-cto-brief-v1.md`
- `docs/architecture/frontend-backend-environment-semantics-v1.md`
- `docs/runbooks/production-deploy-v1.md`
- `docs/runbooks/production-rollback-v1.md`

Update:

- `docs/architecture/system-overview-v1.md`
- `docs/architecture/environment-governance-v1.md`
- `contracts/auth.me.v2.md`
- any frontend UI mapping doc that currently renders `Production` from non-production state
