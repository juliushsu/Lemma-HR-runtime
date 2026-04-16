# Employee Self-Service Language Strategy v1

Status: proposal  
Scope: staging-first contract alignment for employee-facing HR APIs  
Non-goals in this round:
- no large migration rollout
- no frontend translation implementation
- no production rollout

## 1. Current State

### 1.1 Employee locale field

`public.employees.preferred_locale` already exists in the canonical HR employee schema.

Current canonical employee shape already includes:
- `preferred_locale`
- `work_country_code`
- `timezone`

This means the backend already has the minimum employee-level language anchor needed for:
- attendance
- leave
- self-service

### 1.2 Supported employee locale values for v1

Staging-first supported values:
- `zh-TW`
- `en`
- `ja`
- `th`
- `vi`
- `id`
- `tl`
- `my`
- `hi`

This round does not require a DB enum or check constraint migration yet.
These values should first be treated as an application/data contract allowlist.

## 2. Canonical Key Policy

Employee-facing APIs should continue returning canonical keys, not localized display text.

### 2.1 Leave

Canonical leave fields already use keys:
- `leave_type`
- `approval_status`
- MVP route also uses `status`

Examples:
- `annual_leave`
- `sick_leave`
- `pending`
- `approved`
- `rejected`
- `cancelled`

Do not store localized labels such as:
- `年假`
- `病假`
- `已核准`

### 2.2 Attendance

Attendance already uses canonical keys in multiple places:
- `check_type`
- `status_code`
- `approval_status`
- import/result statuses such as `preview_ready`, `imported`, `failed`

Do not store display text in employee-facing operational fields.

### 2.3 Self-service principle

Backend:
- returns canonical keys
- returns employee locale signal

Frontend:
- translates canonical keys into the employee-visible language

## 3. Locale Resolution Order

For employee-facing rendering, resolve locale in this order:

1. employee `preferred_locale`
2. user `locale_preference`
3. company `locale_default`
4. org `locale_default`
5. fallback `en`

Rationale:
- employee self-service should prioritize the employee's own language choice
- user profile locale remains a useful bridge if employee locale is missing
- company/org defaults remain tenant-level fallback only

## 4. API Contract Split

### 4.1 APIs that should return canonical keys only

These APIs should remain canonical and non-localized:
- leave request create/list/detail
- leave approval detail snapshots
- attendance logs
- attendance daily summary
- attendance check / adjustment operational responses
- employee self-service workflow statuses

Typical fields:
- `leave_type`
- `status`
- `approval_status`
- `check_type`
- `status_code`
- `employment_status`

### 4.2 APIs that may return locale hints

These APIs should expose locale hints, but still not translate keys server-side:
- `/api/me`
- employee detail
- employee self-service bootstrap/context endpoints
- leave request detail
- attendance context/bootstrap endpoints

Recommended locale hints:
- `preferred_locale`
- resolved `locale`

### 4.3 APIs that frontend should translate

Frontend should own display translation for:
- leave type labels
- leave approval state labels
- attendance state labels
- empty states
- action button labels
- employee-facing help text

## 5. Staging-First Recommendations

### 5.1 No immediate migration required

Because `employees.preferred_locale` already exists, no urgent staging migration is required just to unlock the contract.

### 5.2 Optional future hardening migration

If we later want stronger data hygiene, staging can add a narrow validation layer:
- app-level allowlist validation first
- DB check constraint later, after existing data audit

That future migration should be staging-first and only after:
- current employee rows are audited
- self-service translation map is stabilized

## 6. API Alignment Checklist

### 6.1 Leave

Keep canonical:
- `leave_type`
- `status`
- `approval_status`

Current implementation slice:
- `GET /api/hr/leave-requests` now returns:
  - `resolved_locale`
  - `locale_source`
- response items remain canonical and non-localized
- backend still does not return translated display text

Current `locale_source` values:
- `employee.preferred_locale`
- `user.locale_preference`
- `company.locale_default`
- `org.locale_default`
- `fallback.en`

### 6.2 Attendance

Keep canonical:
- `check_type`
- `status_code`
- `approval_status`

Recommended next follow-up:
- ensure employee-facing attendance views consume canonical status keys consistently

### 6.3 Self-service

Recommended contract:
- employee-facing bootstrap should include resolved locale
- workflow payloads should remain canonical
- frontend dictionary layer should render locale-specific labels

## 7. Decision Summary

- `employees.preferred_locale` already exists, so no immediate migration is needed
- employee-facing backend responses should stay canonical
- frontend should translate labels from canonical keys
- locale resolution should be employee-first, then user/company/org fallback
- this should remain staging-first until self-service surfaces are consistently aligned
