# Employee Language Skills v1 Proposal (Staging)

## 1) Canonical Table
`employee_language_skills`

Columns (minimal):
- `id` uuid pk
- `org_id` uuid not null
- `company_id` uuid not null
- `employee_id` uuid not null
- `environment_type` text not null
- `is_demo` boolean not null default false
- `language_code` text not null
- `proficiency_level` text not null
- `skill_type` text not null
- `is_primary` boolean not null default false
- `created_at` timestamptz not null default now()
- `updated_at` timestamptz not null default now()
- `created_by` uuid
- `updated_by` uuid

## 2) Enum Suggestions
- `proficiency_level`:
  - `basic`
  - `conversational`
  - `business`
  - `native`
- `skill_type`:
  - `spoken`
  - `written`
  - `reading`
  - `other`

## 3) Uniqueness / Multi-row Rule
- 同員工可有多筆語言能力（允許）。
- 建議 unique:
  - `(employee_id, language_code, skill_type, environment_type)`
- `is_primary=true` 建議部分唯一（每位員工最多一筆 primary）:
  - unique index on `(employee_id, environment_type)` where `is_primary=true`

## 4) RLS (minimal)
- employee self: read-only own skills
- HR / owner / scoped manager: read/write in same org/company/environment
- service_role: full access
- delete 建議限制為 HR/owner，保留 `updated_by` 審計

## 5) API/Function Contract (frontend-ready)
- read:
  - `list_employee_language_skills(employee_id_or_code)`
    - returns `[{ id, language_code, proficiency_level, skill_type, is_primary, updated_at }]`
- write:
  - `upsert_employee_language_skill(payload_jsonb)`
    - input: `employee_id_or_code`, `language_code`, `proficiency_level`, `skill_type`, `is_primary`, `actor_user_id`
    - returns updated row
- delete/disable (optional v1):
  - `delete_employee_language_skill(skill_id, actor_user_id)`

