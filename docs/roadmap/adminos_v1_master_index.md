# AdminOS v1 Master Index

## Product Scope
- Goal: deliver a single canonical admin backend surface for HR+, LC+, and cross-module settings.
- Current focus: stabilize canonical read/write APIs, reduce mock dependency, and keep environment isolation (`demo` / `staging` / `production`).
- Out of immediate scope: advanced AI automation, point ledgers, deep workflow engines, and module-specific heavy customization.

## Sidebar Structure
- Dashboard
- HR+
  - Employees
  - Departments
  - Positions
  - Org Chart
  - Attendance
- LC+
  - Documents
  - Cases
- Settings
  - Company Profile
  - Locations
  - Attendance Boundary
- ACC+
- PO+
- SO+

## Module Status
- HR: Active. Core employee/org chart/attendance APIs are available and connected to canonical data.
- LC: Active. Document/case list+detail APIs are available with demo + production seed paths.
- Settings: Active (Sprint A). Company profile and locations read-only APIs are available.
- ACC: Planned skeleton only.
- PO: Planned skeleton only.
- SO: Planned skeleton only.

## Current Sprint
- Sprint 2B.9.1: System RBAC proposal / contract 對齊
  - System layer 角色邊界：`owner` full、`super_admin` limited、其他角色不可見
  - System pages permission matrix：`admin-users/roles/features/api-keys/billing`
  - 明確 system layer vs organization layer contract

## Attendance Input Channels Status (Pinned)
- LINE: MVP 完成
- Manual Upload: MVP 完成
- External API: converged proposal + shell 完成，待 backend MVP

## Key Docs Index
- [HR+ API Contract](/Users/chishenhsu/Desktop/Codex/Lemma HR+/contracts/hr_plus_mvp_v1_api_contract.md)
- [Sprint A Proposal](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/hr_plus_sprint_a_company_gps_canonical_proposal.md)
- [Staging Runtime Status](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/staging-runtime-status.md)
- [Account Matrix Smoke Sheet](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/account-matrix-smoke-sheet.md)
- [HR API Smoke Checklist](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/smoke/hr_mvp_v1_api_smoke_checklist.md)
- [LC Migration Smoke Checklist](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/smoke/lc_plus_phase1_migration_smoke_checklist.md)
- [System RBAC Proposal](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/roadmap/system_rbac_v1_proposal.md)

## Next Sprint Candidates
1. System RBAC Phase 1.1
- action-level permission code map（逐 endpoint）
- frontend route guard / forbidden state 對齊

2. External API import backend MVP closeout
- 將 external API status 從「待 backend MVP」提升至「MVP 完成」
- 完成最終 smoke + ops runbook

3. Phase 2C integration prep
- LC passive triggers and ERP-style module integration points
- ESG / CaCalLab connector-ready fields and event surface
