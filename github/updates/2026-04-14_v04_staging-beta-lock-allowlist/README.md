# Update Pack: 2026-04-14 Staging Beta Lock Allowlist

This pack is for the minimum-safe staging beta lock follow-up.

## Goal

- document the current staging beta lock model
- separate `beta lock pass`, `membership role`, and `writable allowed`
- add a minimum migration draft for `staging.tester2@lemma.local`
- keep the rollout read-only and avoid allowlist expansion

## Scope

Included in this pack:

- `DOCS/architecture/staging-beta-lock-allowlist-v1.md`
- `DOCS/account-access/staging-account-tier-matrix-v1.md`
- `supabase/migrations/20260414213000_staging_tester2_beta_lock_readonly.sql`

## Non-Goals

- no writable rollout
- no HR partner writable access
- no broad allowlist expansion
- no membership role elevation for `staging.tester2@lemma.local`

## Target GitHub Paths

- `DOCS/architecture/staging-beta-lock-allowlist-v1.md` -> `DOCS/architecture/staging-beta-lock-allowlist-v1.md`
- `DOCS/account-access/staging-account-tier-matrix-v1.md` -> `DOCS/account-access/staging-account-tier-matrix-v1.md`
- `supabase/migrations/20260414213000_staging_tester2_beta_lock_readonly.sql` -> `supabase/migrations/20260414213000_staging_tester2_beta_lock_readonly.sql`

## Notes

- This pack is intentionally narrow.
- This pack only handles `staging.tester2@lemma.local`.
- Passing beta lock after this pack does not imply writable access.
