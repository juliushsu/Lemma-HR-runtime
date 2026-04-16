# Update Pack: 2026-04-14 GitHub Main Path Fix

This pack is for a small documentation-only cleanup on GitHub `main`.

## Goal

- align docs references to the current GitHub path convention
- remove local filesystem path references from shared docs
- add the missing selected-context architecture documents under `DOCS/architecture/`

## Verified GitHub Main Reality Before This Pack

- `README.md` exists
- `contracts/auth.me.v2.md` exists
- `contracts/auth.session.context.v1.md` exists
- `DOCS/README.md` exists
- `DOCS/architecture/system-overview-v1.md` exists
- `DOCS/architecture/environment-governance-v1.md` exists

Missing at the time of packaging:

- `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md`
- `DOCS/architecture/frontend-backend-alignment-v1.md`

## Target GitHub Paths

- `root/README.md` -> `README.md`
- `DOCS/architecture/system-overview-v1.md` -> `DOCS/architecture/system-overview-v1.md`
- `DOCS/architecture/environment-governance-v1.md` -> `DOCS/architecture/environment-governance-v1.md`
- `DOCS/architecture/selected-context-decisions-v1.md` -> `DOCS/architecture/selected-context-decisions-v1.md`
- `DOCS/architecture/selected-context-rollout-v1.md` -> `DOCS/architecture/selected-context-rollout-v1.md`
- `DOCS/architecture/frontend-backend-alignment-v1.md` -> `DOCS/architecture/frontend-backend-alignment-v1.md`

## Notes

- This pack does not change runtime behavior.
- This pack does not enable demo writes.
- This pack does not make `team@lemmaofficial.com` writable.
- This pack exists to reduce CTO/Readdy path confusion and broken-link risk.
