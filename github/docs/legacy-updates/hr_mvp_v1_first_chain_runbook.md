# HR+ MVP v1 First Real-Data Chain Runbook

## 1) Route Contract Freeze (P0)

Canonical API contract is frozen to:
- `/api/me`
- `/api/hr/*`

No dual-track endpoint is allowed.

Verification (already checked in repo):
- `app/api/adapter/hr/v1/*` is fully removed.
- Active HR endpoints exist only under `app/api/hr/*`.

Quick verify command:

```bash
find app/api -maxdepth 6 -type f | sort
```

Expected:
- includes `app/api/me/route.ts`
- includes `app/api/hr/...`
- does not include `app/api/adapter/hr/v1/...`

## 2) Migration Runbook (P0)

Run order:
1. `supabase/migrations/20260401144000_core_schema_rbac_auth_locale_rls.sql`
2. `supabase/migrations/20260401150000_hr_mvp_v1_canonical_schema.sql`

Reason:
- migration #1 creates foundation objects:
  - `environment_type` enum
  - `role_type` enum
  - `scope_type` enum
  - base tables: `organizations/companies/branches/users/memberships`
  - helper `can_access_row(...)`
- migration #2 depends on those base tables and membership RBAC context.

Dependencies:
- extension: `pgcrypto` (for `gen_random_uuid()`)
- enum/type dependency:
  - #1 creates `environment_type/role_type/scope_type`
  - #2 uses plain `text check (...)` for HR domain enums, but still references base tables and membership.

RLS enable sequence:
1. Create table
2. Create helper functions (scope helpers)
3. `alter table ... enable row level security`
4. `create policy ...`

This sequence is already followed in both migration files.

Minimal verification SQL (read-only):

```sql
-- 1) foundation + HR tables present
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'organizations','companies','branches','users','memberships',
    'employees','departments','positions','employee_assignments',
    'attendance_policies','employee_attendance_profiles',
    'attendance_logs','attendance_adjustments'
  )
order by table_name;

-- 2) key helpers present
select proname
from pg_proc
where proname in ('can_access_row','can_read_scope','can_write_scope','current_jwt_employee_id')
order by proname;

-- 3) RLS enabled
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'employees','departments','positions','employee_assignments',
    'attendance_policies','employee_attendance_profiles',
    'attendance_logs','attendance_adjustments'
  )
order by c.relname;

-- 4) policy existence
select schemaname, tablename, policyname
from pg_policies
where schemaname = 'public'
  and tablename in (
    'employees','departments','positions','employee_assignments',
    'attendance_policies','employee_attendance_profiles',
    'attendance_logs','attendance_adjustments'
  )
order by tablename, policyname;
```

## 3) Employee Linkage (P0)

Current implementation uses 3 layers:
1. `users` table: auth principal profile row
2. `memberships` table: org/company/branch scope + role
3. JWT claim `employee_id`: used by RLS helper `current_jwt_employee_id()` for "employee can read own attendance"

Minimum viable approach (v1):
1. Keep `/api/me` as the source of current user context.
2. Keep RBAC scope via `memberships` (already used by `/api/hr/*`).
3. Add `employee_id` into JWT custom claims at sign-in/session mint time.
4. Maintain mapping in DB with `employees.user_id -> users.id` so backend can resolve claim generation source.

Fallback before claim pipeline is ready:
- temporarily rely on manager/admin scope for attendance reads.
- treat self-read as backend-validated path (not pure RLS self-claim path) until claim rollout is done.

## 4) Smoke Test Checklist (P0)

See dedicated checklist:
- `docs/smoke/hr_mvp_v1_api_smoke_checklist.md`

## 5) Seed Data (P0)

Seed SQL:
- `supabase/seeds/base/hr_mvp_v1_minimal_seed.sql`

Optional runner:
- `scripts/seed_hr_mvp_v1_minimal.sh`
