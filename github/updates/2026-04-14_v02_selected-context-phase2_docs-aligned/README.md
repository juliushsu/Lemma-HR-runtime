# Update Pack: 2026-04-14 Selected Context Phase 2 (DOCS aligned)

This pack is aligned to the current GitHub `main` path convention where architecture documents are under `DOCS/architecture/` with uppercase `DOCS`.

## Verified GitHub Main State

Confirmed on GitHub `main`:

- `DOCS/README.md` exists
- `DOCS/architecture/environment-governance-v1.md` exists

Not found on GitHub `main` at the time of packaging:

- `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md`
- `DOCS/architecture/frontend-backend-alignment-v1.md`

## Target GitHub Paths

- `root/README.md` -> `README.md`
- `contracts/auth.me.v2.md` -> `contracts/auth.me.v2.md`
- `contracts/auth.session.context.v1.md` -> `contracts/auth.session.context.v1.md`
- `DOCS/architecture/system-overview-v1.md` -> `DOCS/architecture/system-overview-v1.md`
- `DOCS/architecture/selected-context-decisions-v1.md` -> `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md` -> `DOCS/architecture/selected-context-rollout-v1.md`
- `DOCS/architecture/frontend-backend-alignment-v1.md` -> `DOCS/architecture/frontend-backend-alignment-v1.md`

## Scope

- selected context decision record
- selected context rollout skeleton
- frontend/backend alignment contract explanation
- contract refresh for `auth.me.v2` and `auth.session.context.v1`

## Notes

- This pack follows GitHub path reality first.
- No production runtime change is included.
- Demo remains read-only.
- `team@lemmaofficial.com` remains non-writable.
