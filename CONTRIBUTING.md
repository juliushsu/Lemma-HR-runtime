# Contributing to Lemma HR+

## Purpose

This repository supports four-way collaboration between product, implementation, frontend integration, and testing. The goal of this guide is to keep work reviewable, predictable, and safe across `demo`, `staging-write`, and later `production`.

## Ground Rules

- Do not make production-only assumptions when writing docs, contracts, or scripts.
- Do not mix demo narrative data with writable staging data.
- Do not rely on `memberships[0]` as the long-term current context.
- Do not overwrite seed stories to make smoke tests pass.
- Prefer additive migrations and explicit rollback notes.

## Expected Workflow

1. Start with the contract or doc when a change affects shared behavior.
2. Keep implementation scoped to one concern per PR when possible.
3. Call out environment impact in the PR description.
4. If a change touches seeds, update the seed registry in the same PR.
5. If a change touches auth or scope selection, update [auth.me.v2](</Users/chishenhsu/Desktop/Codex/Lemma HR+/contracts/auth.me.v2.md>).

## Branch and PR Scope

- Branch prefix recommendation: `docs/`, `contracts/`, `seed/`, `migration/`, `api/`
- Preferred PR size: one governance topic, one contract topic, or one runtime topic
- Avoid bundling `docs + seed moves + runtime behavior + migrations` unless tightly related

## Naming Rules

### Migrations

- Format: `YYYYMMDDHHMMSS_short_scope_vN.sql`
- Examples:
  - `20260414103000_environment_access_mode_v1.sql`
  - `20260414104500_selected_context_contract_alignment_v1.sql`

### Seeds

- Format: `YYYYMMDD_or_feature_scope_seed.sql` for dated environment seeds
- Format: `feature_scope_seed.sql` for stable reusable base seeds
- Place each file in exactly one layer:
  - `base`
  - `demo`
  - `staging`

### Docs

- Architecture docs: `docs/architecture/<topic>-vN.md`
- Product docs: `docs/product/<topic>-vN.md`
- Runbooks: `docs/runbooks/<topic>-vN.md`
- Contracts: `contracts/<schema-or-endpoint>-vN.md`

### Scripts

- Use verb-oriented names: `seed_*`, `verify_*`, `reset_*`, `smoke_*`
- Scripts must declare target environment in comments or filename when not obvious

## Seed Safety

- `demo` seeds are protected and should be treated as showcase assets.
- `staging` seeds can be replayed and reset.
- `base` seeds may be depended on by both demo and staging, but must stay narrative-neutral.
- If a seed is rerunnable, document that explicitly in the seed registry.

## Review Checklist

- Is the environment scope explicit?
- Is the contract documented?
- Are demo and staging responsibilities kept separate?
- Is the rollback path clear?
- Are new filenames aligned to naming rules?
