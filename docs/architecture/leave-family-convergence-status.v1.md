# Leave Family Convergence Status v1

Status: phase status summary for Phase 3 planning

Purpose:

- summarize the convergence points already completed in Phase 1 and Phase 2
- name the remaining transitional compatibility clearly
- define what Phase 3 means before further route-family cleanup begins

This document is a short status summary.
It is not a new contract and it does not itself change runtime behavior.

## 1. Completed Convergence

The following convergence points are already considered completed for leave family:

- submit payload convergence
  `POST /api/hr/leave/requests` now accepts both legacy `start_at` / `end_at` and canonical `start_date` / `end_date`, then normalizes them into one server-side submit interpretation.
- action actor convergence
  `approve`, `reject`, and `cancel` now share one server-side actor resolution rule: authenticated user at the auth boundary, selected-context employee binding at the workflow boundary.
- self history canonical switch
  self history is no longer treated as a permanently separate MVP family concern; it now has canonical-mode handling under `GET /api/hr/leave/requests` with self-scoped interpretation.
- HR list canonical switch
  HR/admin list is treated as canonical under `GET /api/hr/leave/requests`, not under the MVP write family.
- read path scope split removal
  read-path interpretation is now documented and implemented as one canonical family with scoped modes, instead of keeping self history and HR list as separate long-term route families.

## 2. Remaining Transitional Parts

The following parts are still transitional compatibility and should not be treated as long-term architecture:

- `/api/hr/leave-requests` write family remains in place as temporary compatibility for submit and action callers that have not switched yet.
- MVP compatibility routes are still present where old callers may still use:
  - `POST /api/hr/leave-requests`
  - `POST /api/hr/leave-requests/:id/approve`
  - `POST /api/hr/leave-requests/:id/reject`
  - `POST /api/hr/leave-requests/:id/cancel`
- legacy frontend component usage, if still present outside this round's API work, remains transitional only and must not be used as the architecture decision source.

## 3. What Phase 3 Means

Phase 3 is the route-family retirement phase.

Direct definition:

- Phase 3 does include the submit write route switch.
  The long-term write entrypoint should become `POST /api/hr/leave/requests`, not `/api/hr/leave-requests`.
- Phase 3 does include MVP route deprecation.
  The MVP write family should move from temporary compatibility to bounded deprecation, then removal when callers are migrated.
- Phase 3 does include legacy component deprecation where legacy components still depend on the MVP write family.
  UI compatibility may exist during migration, but legacy component dependence should not remain as a permanent reason to preserve the old route family.

Phase 3 does not mean a new route family.
It means finishing the switch onto the canonical family already chosen in the convergence decision.

## 4. Non-Goals

This convergence status does not expand into adjacent domains.

Non-goals:

- do not touch attendance
- do not touch payroll
- do not touch recruiting
- do not touch employee detail
- do not do schema changes

## 5. Recommended Next Implementation Step

Recommended single next step:

- switch the active submit write caller path to `POST /api/hr/leave/requests`, while leaving `/api/hr/leave-requests` in temporary compatibility mode for a bounded migration window

Reason:

- submit is the smallest Phase 3 starting point with the clearest payoff
- canonical submit capability already exists
- this begins real route-family convergence without requiring schema change or broader workflow removal in the same round
