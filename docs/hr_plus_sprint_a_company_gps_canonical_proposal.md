# HR+ Sprint A Proposal: Company Settings + GPS Attendance Boundary

## 1) Scope / Non-goals

### Scope (this proposal only)
- Define minimal canonical schema for:
  - `company_profile` / `company_settings`
  - `locations` / `branches`
  - `attendance_boundary_settings`
- Define minimal API contract for:
  - `GET /api/settings/company-profile`
  - `GET /api/settings/locations`
- Define demo seed proposal
- Define smoke checklist

### Non-goals
- Payroll
- Scheduling engine
- LC+ expansion
- API envelope changes

---

## 2) Canonical Schema Proposal

Design principle: maximize reuse of existing core tables (`companies`, `branches`) and add only the minimum skeleton tables needed for settings and GPS boundary.

## 2.1 `company_settings` (new)

Purpose: canonical settings extension for each company scope.

```sql
create table if not exists company_settings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  company_legal_name text not null,
  tax_id text,
  address text,
  timezone text not null default 'Asia/Taipei',
  default_locale text not null default 'zh-TW',
  is_attendance_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (org_id, company_id, environment_type)
);
```

---

## 2.2 `branches` as canonical `locations` (extend existing table)

Existing `branches.name` is used as `location_name`.

Add minimal columns:

```sql
alter table branches
  add column if not exists address text,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists is_attendance_enabled boolean not null default true;
```

Suggested constraints:

```sql
alter table branches
  add constraint branches_latitude_range_chk
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  add constraint branches_longitude_range_chk
    check (longitude is null or (longitude >= -180 and longitude <= 180));
```

---

## 2.3 `attendance_boundary_settings` (new)

Purpose: provide company default and branch-specific GPS boundary skeleton for check-in checks.

```sql
create table if not exists attendance_boundary_settings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  branch_id uuid references branches(id) on delete cascade,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  checkin_radius_m int not null default 150 check (checkin_radius_m >= 10 and checkin_radius_m <= 5000),
  is_attendance_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create unique index if not exists attendance_boundary_company_default_uniq
on attendance_boundary_settings (org_id, company_id, environment_type)
where branch_id is null;

create unique index if not exists attendance_boundary_branch_uniq
on attendance_boundary_settings (org_id, company_id, branch_id, environment_type)
where branch_id is not null;
```

Fallback rule (runtime):
- Use branch-level boundary first (`branch_id = request.branch_id`)
- If missing, fallback to company default (`branch_id is null`)

---

## 2.4 Canonical `company_profile` object

`company_profile` is API-level canonical object (can be implemented as query join, no separate table required):
- from `companies` + `company_settings`

Minimum required fields:
- `company_legal_name`
- `tax_id`
- `address`
- `timezone`
- `default_locale`
- `is_attendance_enabled`

---

## 3) Minimal API Contract Proposal

Envelope remains existing canonical:
- `schema_version`
- `data`
- `meta`
- `error`

## 3.1 `GET /api/settings/company-profile`

### Query
- `org_id` (optional if inferred from membership)
- `company_id` (optional if inferred)
- `environment_type` (optional if inferred)

### Success (`200`)
- `schema_version = "settings.company_profile.v1"`

```json
{
  "schema_version": "settings.company_profile.v1",
  "data": {
    "company_profile": {
      "org_id": "uuid",
      "company_id": "uuid",
      "company_name": "Lemma Demo Company",
      "company_legal_name": "Lemma Demo Co., Ltd.",
      "tax_id": "12345678",
      "address": "Taipei City, Taiwan",
      "timezone": "Asia/Taipei",
      "default_locale": "zh-TW",
      "is_attendance_enabled": true
    }
  },
  "meta": {},
  "error": null
}
```

### Errors
- `401 UNAUTHORIZED`
- `403 SCOPE_FORBIDDEN`
- `404 COMPANY_PROFILE_NOT_FOUND`
- `500 INTERNAL_ERROR`

---

## 3.2 `GET /api/settings/locations`

### Query
- `org_id` (optional if inferred)
- `company_id` (optional if inferred)
- `environment_type` (optional if inferred)
- `branch_id` (optional filter)

### Success (`200`)
- `schema_version = "settings.location.list.v1"`

```json
{
  "schema_version": "settings.location.list.v1",
  "data": {
    "items": [
      {
        "branch_id": "uuid",
        "location_name": "Taipei HQ",
        "address": "Xinyi Dist., Taipei",
        "latitude": 25.0339640,
        "longitude": 121.5644680,
        "checkin_radius_m": 150,
        "is_attendance_enabled": true
      }
    ]
  },
  "meta": {},
  "error": null
}
```

### Errors
- `401 UNAUTHORIZED`
- `403 SCOPE_FORBIDDEN`
- `500 INTERNAL_ERROR`

---

## 4) Demo Seed Proposal (not payroll/scheduling)

Target scope only:
- `org_id = 10000000-0000-0000-0000-000000000002`
- `company_id = 20000000-0000-0000-0000-000000000002`
- `environment_type = 'demo'`
- `is_demo = true`

### 4.1 Seed `company_settings`

```sql
insert into company_settings (
  org_id, company_id, environment_type, is_demo,
  company_legal_name, tax_id, address, timezone, default_locale, is_attendance_enabled
) values (
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  'demo',
  true,
  'Lemma Demo Co., Ltd.',
  '53535353',
  'Xinyi Dist., Taipei City, Taiwan',
  'Asia/Taipei',
  'zh-TW',
  true
)
on conflict (org_id, company_id, environment_type) do update
set company_legal_name = excluded.company_legal_name,
    tax_id = excluded.tax_id,
    address = excluded.address,
    timezone = excluded.timezone,
    default_locale = excluded.default_locale,
    is_attendance_enabled = excluded.is_attendance_enabled,
    updated_at = now();
```

### 4.2 Seed `branches` location fields

```sql
update branches
set address = 'Xinyi Dist., Taipei City, Taiwan',
    latitude = 25.0339640,
    longitude = 121.5644680,
    is_attendance_enabled = true,
    updated_at = now()
where id = '30000000-0000-0000-0000-000000000002'
  and org_id = '10000000-0000-0000-0000-000000000002'
  and company_id = '20000000-0000-0000-0000-000000000002'
  and environment_type = 'demo'
  and is_demo = true;
```

### 4.3 Seed `attendance_boundary_settings`

```sql
-- company default
insert into attendance_boundary_settings (
  org_id, company_id, branch_id, environment_type, is_demo,
  checkin_radius_m, is_attendance_enabled
) values (
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  null,
  'demo',
  true,
  150,
  true
)
on conflict do nothing;

-- branch override
insert into attendance_boundary_settings (
  org_id, company_id, branch_id, environment_type, is_demo,
  checkin_radius_m, is_attendance_enabled
) values (
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000002',
  'demo',
  true,
  120,
  true
)
on conflict do nothing;
```

---

## 5) Smoke Checklist Proposal

## 5.1 Auth / Scope
- account: `demo.admin@lemma.local`
- account: `staging.superadmin@lemma.local`
- verify both can access expected scope (`demo` vs `production`)

## 5.2 `GET /api/settings/company-profile`
- expect `200`
- expect `schema_version = settings.company_profile.v1`
- expect fields exist:
  - `company_legal_name`
  - `tax_id`
  - `address`
  - `timezone`
  - `default_locale`
  - `is_attendance_enabled`

## 5.3 `GET /api/settings/locations`
- expect `200`
- expect `schema_version = settings.location.list.v1`
- expect `data.items.length >= 1` for demo
- each item has:
  - `location_name`
  - `latitude` / `longitude`
  - `checkin_radius_m`
  - `is_attendance_enabled`

## 5.4 Error paths
- no token -> `401`
- wrong scope -> `403`
- profile missing -> `404` (`company-profile` only)

---

## 6) Acceptance Criteria (Sprint A)

- Canonical schema approved:
  - `company_settings`
  - `branches` location extension
  - `attendance_boundary_settings`
- API contract approved:
  - `GET /api/settings/company-profile`
  - `GET /api/settings/locations`
- Demo seed plan approved for `demo` scope only
- Smoke checklist approved
