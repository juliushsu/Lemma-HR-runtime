# Seed Registry

## Purpose

Seeds are organized by intent, not only by feature. This prevents demo story data from being treated like disposable staging fixtures.

## Layers

### `base/`

Reusable dependency seeds that can support either demo or staging flows.

### `demo/`

Protected narrative seeds for showcase and product storytelling. These are not general smoke targets.

### `staging/`

Writable internal validation seeds for sandbox and QA flows.

## Current Registry

| File | Layer | Purpose | Safe to replay |
| --- | --- | --- | --- |
| `base/hr_mvp_v1_minimal_seed.sql` | base | HR baseline records | Yes, with environment awareness |
| `base/leave_policy_engine_minimal_seed.sql` | base | Leave policy baseline | Yes |
| `base/leave_policy_engine_backfill_hr_display_v1.sql` | base | Display/backfill support for leave policy data | Caution |
| `base/employee_language_skills_v1_seed.sql` | base | Language skill fixture support | Yes |
| `demo/hr_mvp_v1_demo_minimal_seed.sql` | demo | Demo HR baseline | Protected replay only |
| `demo/hr_mvp_v1_demo_attendance_minimal_seed.sql` | demo | Demo attendance story baseline | Protected replay only |
| `demo/lc_plus_phase1_demo_seed.sql` | demo | LC+ demo narrative | Protected replay only |
| `demo/onboarding_minimal_demo_seed.sql` | demo | Demo onboarding story | Protected replay only |
| `demo/sprint_a_company_gps_demo_seed.sql` | demo | Demo GPS/company story | Protected replay only |
| `staging/20260408_sandbox_portal_narrative_seed.sql` | staging | Portal sandbox narrative for writable validation | Yes, staging only |
| `staging/20260408_sandbox_portal_visibility_minimal.sql` | staging | Portal visibility prerequisite for sandbox | Yes, staging only |

## Rules

- Never add a demo story seed to `staging/`.
- Never add a general smoke fixture to `demo/`.
- Update this registry whenever a seed is added, moved, renamed, or repurposed.
