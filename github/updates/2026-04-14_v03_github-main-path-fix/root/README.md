# Lemma HR+

Lemma HR+ is the shared working repository for the product backend, Supabase schema, API contracts, seed strategy, and operating docs used by the core collaboration loop:

- Product owner
- Readdy
- Codex
- Test partners

This repository is intentionally kept as a single project for now. The goal of this governance pass is not to split it into multiple repos, but to make the current structure predictable, auditable, and safe for multi-person collaboration.

## Working Principles

- `demo` and `staging-write` are different environments and must never share mutable data.
- Demo narrative data is protected product storytelling data, not disposable test data.
- `memberships[0]` must not be treated as the permanent current context.
- Contracts are written down before behavior is expanded.
- Migrations are append-only and seeds are layered by purpose.

## Repository Shape

```text
app/                  Next.js app and API route handlers
contracts/            Frontend/backend API contracts
DOCS/                 Architecture, product status, runbooks, handoff docs
scripts/              Repeatable helper scripts
supabase/migrations/  Database migrations and RLS changes
supabase/seeds/       Seed layers: base / demo / staging
```

## Environment Vocabulary

- `production`: live customer data and live write path
- `demo`: protected narrative orgs for showcase and walkthroughs
- `sandbox` / `staging-write`: writable internal validation space
- `seed`: bootstrap or fixture-style records used for controlled setup

Canonical guidance lives in:

- `DOCS/architecture/system-overview-v1.md`
- `DOCS/architecture/environment-governance-v1.md`
- `DOCS/architecture/rbac-v1.md`
- `contracts/auth.me.v2.md`
- `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md`
- `contracts/auth.session.context.v1.md`

## Seed Layers

- `supabase/seeds/base/`: reusable baseline data, safe as dependency seeds
- `supabase/seeds/demo/`: protected narrative demo seeds, never general smoke targets
- `supabase/seeds/staging/`: writable staging and sandbox validation seeds

See `supabase/seeds/README.md` before running or adding any seed.

## Collaboration Flow

1. Write or update the contract/doc first when changing shared behavior.
2. Keep migrations additive and timestamped.
3. Keep demo and staging changes separate, even when the business story is similar.
4. Use PRs with explicit scope, risk, and environment notes.

## Current Constraint

This repository is governed through GitHub at `juliushsu/Lemma-HR-`. Contracts and architecture references should be described using repository-relative paths, not local filesystem paths.
