# GitHub Upload Index

This directory is a local staging area for files that should be uploaded into the real GitHub repository.

Use the file inside `github/` as the upload source, and place it into the matching target path shown below.

## Root Files

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/root/README.md` | `README.md` |
| `github/root/CONTRIBUTING.md` | `CONTRIBUTING.md` |
| `github/root/CHANGELOG.md` | `CHANGELOG.md` |

## GitHub Meta

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/.github/pull_request_template.md` | `.github/pull_request_template.md` |

## Contracts

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/contracts/auth.me.v2.md` | `contracts/auth.me.v2.md` |
| `github/contracts/auth.session.context.v1.md` | `contracts/auth.session.context.v1.md` |

## Architecture Docs

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/docs/architecture/system-overview-v1.md` | `docs/architecture/system-overview-v1.md` |
| `github/docs/architecture/environment-governance-v1.md` | `docs/architecture/environment-governance-v1.md` |
| `github/docs/architecture/rbac-v1.md` | `docs/architecture/rbac-v1.md` |
| `github/docs/architecture/selected-context-decisions-v1.md` | `docs/architecture/selected-context-decisions-v1.md` |
| `github/docs/architecture/selected-context-rollout-v1.md` | `docs/architecture/selected-context-rollout-v1.md` |

## Product Docs

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/docs/product/module-status-v1.md` | `docs/product/module-status-v1.md` |
| `github/docs/product/demo-story-v1.md` | `docs/product/demo-story-v1.md` |

## Runbooks

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/docs/runbooks/demo-reset-v1.md` | `docs/runbooks/demo-reset-v1.md` |
| `github/docs/runbooks/staging-seed-v1.md` | `docs/runbooks/staging-seed-v1.md` |

## Legacy Doc Updates

These are existing files that were updated to point at the new seed layout.

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/docs/legacy-updates/hr_mvp_v1_first_chain_runbook.md` | `docs/hr_mvp_v1_first_chain_runbook.md` |
| `github/docs/legacy-updates/hr_mvp_v1_api_smoke_checklist.md` | `docs/smoke/hr_mvp_v1_api_smoke_checklist.md` |
| `github/docs/legacy-updates/lc_plus_phase1_migration_smoke_checklist.md` | `docs/smoke/lc_plus_phase1_migration_smoke_checklist.md` |

## Scripts

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/scripts/seed_hr_mvp_v1_minimal.sh` | `scripts/seed_hr_mvp_v1_minimal.sh` |
| `github/scripts/seed_lc_plus_phase1_demo.sh` | `scripts/seed_lc_plus_phase1_demo.sh` |

## Seed Registry

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/supabase/seeds/README.md` | `supabase/seeds/README.md` |

## Base Seeds

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/supabase/seeds/base/hr_mvp_v1_minimal_seed.sql` | `supabase/seeds/base/hr_mvp_v1_minimal_seed.sql` |
| `github/supabase/seeds/base/leave_policy_engine_minimal_seed.sql` | `supabase/seeds/base/leave_policy_engine_minimal_seed.sql` |
| `github/supabase/seeds/base/leave_policy_engine_backfill_hr_display_v1.sql` | `supabase/seeds/base/leave_policy_engine_backfill_hr_display_v1.sql` |
| `github/supabase/seeds/base/employee_language_skills_v1_seed.sql` | `supabase/seeds/base/employee_language_skills_v1_seed.sql` |

## Demo Seeds

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/supabase/seeds/demo/hr_mvp_v1_demo_minimal_seed.sql` | `supabase/seeds/demo/hr_mvp_v1_demo_minimal_seed.sql` |
| `github/supabase/seeds/demo/hr_mvp_v1_demo_attendance_minimal_seed.sql` | `supabase/seeds/demo/hr_mvp_v1_demo_attendance_minimal_seed.sql` |
| `github/supabase/seeds/demo/lc_plus_phase1_demo_seed.sql` | `supabase/seeds/demo/lc_plus_phase1_demo_seed.sql` |
| `github/supabase/seeds/demo/onboarding_minimal_demo_seed.sql` | `supabase/seeds/demo/onboarding_minimal_demo_seed.sql` |
| `github/supabase/seeds/demo/sprint_a_company_gps_demo_seed.sql` | `supabase/seeds/demo/sprint_a_company_gps_demo_seed.sql` |

## Staging Seeds

| Local upload source | Target path in GitHub |
| --- | --- |
| `github/supabase/seeds/staging/20260408_sandbox_portal_narrative_seed.sql` | `supabase/seeds/staging/20260408_sandbox_portal_narrative_seed.sql` |
| `github/supabase/seeds/staging/20260408_sandbox_portal_visibility_minimal.sql` | `supabase/seeds/staging/20260408_sandbox_portal_visibility_minimal.sql` |

## Notes

- This folder is only a local upload organizer.
- The source-of-truth working files still live in the main project paths.
- If you want, the next pass can also generate a smaller `github/upload-batch-1/`, `upload-batch-2/` split for stepwise manual upload.

## Newly Refreshed In This Pass

- `github/root/README.md`
- `github/contracts/auth.me.v2.md`
- `github/contracts/auth.session.context.v1.md`
- `github/docs/architecture/system-overview-v1.md`
- `github/docs/architecture/selected-context-decisions-v1.md`
- `github/docs/architecture/selected-context-rollout-v1.md`
