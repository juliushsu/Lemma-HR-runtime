# HR+ MVP v1 Canonical Schema + API Contract

## Scope
This version is limited to:
1. employee
2. org chart
3. attendance

Excluded from this version:
- leave
- payroll calculation
- performance
- ATS
- workflow engine
- document upload workflow
- advanced scheduling rules
- multi-country labor law engine

## Canonical Principles
- DB naming: `snake_case`
- API naming: `snake_case`
- enum values: lowercase underscore style (example: `active`, `on_leave`, `manual_adjusted`)
- Frontend must use adapter APIs only, and must not query database tables directly

## Mandatory Multi-Tenant Columns (all core tables)
- `org_id`
- `company_id`
- `environment_type`
- `is_demo`
- `branch_id` (required only for branch-related tables; nullable in MVP schema)

## Mandatory Audit Columns (all core tables)
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

## Soft-Delete Rules
- `employees`: no hard delete; use `employment_status`
- `attendance_logs`: no hard delete; use `is_valid` and `is_adjusted`

## Canonical Tables (v1)
- `employees`
- `departments`
- `positions`
- `employee_assignments`
- `attendance_policies`
- `employee_attendance_profiles`
- `attendance_logs`
- `attendance_adjustments`

Reference migration:
- `/supabase/migrations/20260401150000_hr_mvp_v1_canonical_schema.sql`

## Unified Response Envelope

```json
{
  "schema_version": "xxx.v1",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-01T12:00:00Z"
  },
  "error": null
}
```

## API Endpoints (v1)

### Employee
1. `GET /api/hr/employees` => `hr.employee.list.v1`
2. `GET /api/hr/employees/:id` => `hr.employee.detail.v1`
3. `POST /api/hr/employees` => `hr.employee.create.v1`
4. `PATCH /api/hr/employees/:id` => `hr.employee.update.v1`

### Org Chart
1. `GET /api/hr/org-chart` => `hr.org_chart.v1`
2. `GET /api/hr/departments` => `hr.department.list.v1`
3. `POST /api/hr/departments` => `hr.department.create.v1`
4. `GET /api/hr/positions` => `hr.position.list.v1`

### Attendance
1. `GET /api/hr/attendance/logs` => `hr.attendance.log.list.v1`
2. `POST /api/hr/attendance/check` => `hr.attendance.check.v1`
3. `GET /api/hr/attendance/daily-summary` => `hr.attendance.daily_summary.v1`
4. `POST /api/hr/attendance/adjustments` => `hr.attendance.adjustment.create.v1`

## Error Codes

### Employee
- `EMPLOYEE_NOT_FOUND`
- `EMPLOYEE_CODE_ALREADY_EXISTS`
- `INVALID_EMPLOYMENT_STATUS`
- `INVALID_MANAGER_REFERENCE`

### Department / Position
- `DEPARTMENT_NOT_FOUND`
- `DEPARTMENT_CODE_ALREADY_EXISTS`
- `POSITION_NOT_FOUND`
- `POSITION_CODE_ALREADY_EXISTS`

### Attendance
- `ATTENDANCE_POLICY_NOT_FOUND`
- `ATTENDANCE_LOG_NOT_FOUND`
- `INVALID_CHECK_TYPE`
- `ATTENDANCE_ADJUSTMENT_NOT_ALLOWED`
- `ATTENDANCE_ALREADY_INVALIDATED`

## RLS / Scope Minimum Rules

### Employees / Departments / Positions
- same `org_id` can read
- `company` scope is restricted to `company_id`
- `branch` scope can be restricted to `branch_id`
- `viewer` can read in scope
- `manager` can read in scope
- `admin` and `super_admin` can write in scope

### Attendance
- employee can read own attendance
- manager can read attendance in scope
- admin and super_admin can adjust attendance in scope
- demo org cannot read production org data

## Implemented Route Files
- `/app/api/hr/employees/route.ts`
- `/app/api/hr/employees/[id]/route.ts`
- `/app/api/hr/departments/route.ts`
- `/app/api/hr/positions/route.ts`
- `/app/api/hr/org-chart/route.ts`
- `/app/api/hr/attendance/logs/route.ts`
- `/app/api/hr/attendance/check/route.ts`
- `/app/api/hr/attendance/daily-summary/route.ts`
- `/app/api/hr/attendance/adjustments/route.ts`
- shared helpers: `/app/api/hr/_lib.ts`
