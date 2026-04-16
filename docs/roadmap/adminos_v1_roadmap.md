# AdminOS v1 Roadmap

## Planning Principles
- Canonical first: schema and API consistency before feature breadth.
- Scope isolation: strict `demo` / `staging` / `production` separation.
- Read-first rollout: stabilize list/detail and fallback behavior before complex writes.

## Current Delivery Snapshot (Pinned)
- LINE: MVP 完成
- Manual Upload: MVP 完成
- External API: converged proposal + shell 完成，待 backend MVP

## Sprint 2B.9.1 (Current): System RBAC Contract Alignment

### Scope
1. 定義 system layer 可見角色（owner / super_admin / others）
2. 凍結 system pages 最小 permission matrix：
- `admin-users`
- `roles`
- `features`
- `api-keys`
- `billing`
3. 定義 system layer 與 organization layer 邊界

### Contract Decision (Pinned)
- `owner`: system full access
- `super_admin`: system visible with limited actions
- other roles: system not visible

Reference:
- [System RBAC Proposal](/Users/chishenhsu/Desktop/Codex/Lemma HR+/docs/roadmap/system_rbac_v1_proposal.md)

## Phase 2A: Company + GPS + Attendance Core

### Schema Priority
1. `company_settings` completeness and constraints
2. `attendance_boundary_settings` fallback model (company default + branch override)
3. `branches` geolocation quality guardrails (range checks, nullable handling)

### API Priority
1. `GET /api/settings/company-profile` stabilization
2. `GET /api/settings/locations` stabilization
3. Attendance check dependency wiring to boundary fallback resolution

### UI Priority
1. Settings read pages using canonical routes (no mock fallback as primary source)
2. Location list/map-ready data presentation
3. Attendance boundary visibility in settings (read-only first)

## Phase 2B: Shift / Leave / Payroll Skeleton

### Schema Priority
1. `shift_templates` / `shift_assignments` skeleton
2. `leave_types` / `leave_requests` skeleton
3. `payroll_cycles` / `payroll_items` skeleton (minimal non-calculation shape)

### API Priority
1. Read-only list/detail for shift/leave/payroll entities
2. Minimal filters + scope checks + canonical envelope
3. Explicit placeholders for write APIs (not enabled by default)

### UI Priority
1. Basic pages showing canonical list data
2. Empty/error/demo state consistency
3. No heavy editors or engines in this phase

## Phase 2C: LC+ Passive Triggers + ESG / CaCalLab Integration

### Schema Priority
1. Passive trigger records (cross-module references only)
2. Integration event outbox schema (idempotent dispatch fields)
3. ESG / CaCalLab linkage metadata table(s)

### API Priority
1. Read-only trigger/event visibility endpoints
2. Minimal integration status endpoint
3. Contract-safe extension fields for downstream connectors

### UI Priority
1. Trigger/activity visibility panel
2. Integration status readout
3. No autonomous action workflows in this phase

## Cross-phase Quality Gates
- Canonical envelope unchanged (`schema_version`, `data`, `meta`, `error`)
- Scope/RLS smoke for demo and staging accounts
- Seed reproducibility checks for demo/staging
- Deployment smoke with explicit endpoint pass/fail summary
