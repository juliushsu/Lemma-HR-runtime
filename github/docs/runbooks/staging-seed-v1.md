# Staging Seed v1

## Purpose

Define how staging-write data should be seeded and re-seeded without affecting demo narrative integrity.

## Principles

- Staging-write is the default place for QA and exploratory mutation.
- Staging seeds may be replayed.
- Staging seeds should be explicit about whether they are additive, idempotent, or destructive.
- Staging data must not be sourced from protected demo org tables by copy-paste mutation.

## Seed Layers

### Base

- reusable dependencies shared by other seed layers

### Staging

- writable internal validation records
- sandbox portal stories
- QA fixtures and smoke prerequisites

## Recommended Flow

1. Apply required migrations.
2. Run needed `base` seeds.
3. Run target `staging` seeds for the validation scenario.
4. Run smoke or acceptance scripts against staging-write only.

## Current Notes

- Portal sandbox narrative seeds belong to the `staging` layer.
- If a new writable demo-like story is needed for QA, create it under `staging`, not `demo`.

## Future Script Direction

- `scripts/seed_staging_base.sh`
- `scripts/seed_staging_portal_story.sh`
- `scripts/verify_staging_scope.sh`
