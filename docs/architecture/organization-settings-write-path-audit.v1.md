# Organization Settings Write-Path Audit v1

## Purpose

Audit the current organization settings family and determine which modules already have a usable write path, which remain read-only, and which are still missing as canonical settings APIs.

This audit focuses on:

- company profile
- branch and GPS settings
- locale and timezone
- attendance policy/settings
- leave policy/settings
- attendance adjustment permission settings

This is an audit and implementation-prep document only.

It does not introduce new APIs in this round.

## Audit Summary

| Module | Current status | Current runtime/path | Canonical runtime target | Notes |
| --- | --- | --- | --- | --- |
| Company data | `read only` | `GET /api/settings/company-profile` | `Railway` | read exists, no matching settings-family write route |
| Branch and GPS | `write ready` | read: `GET /api/settings/locations`; write: `POST /api/locations`, `PATCH /api/locations/:id` | `Railway` | real write exists, but it sits on legacy staging-only attendance phase path, not canonical settings family |
| Locale and timezone | `read only` | company-level read via `GET /api/settings/company-profile` | `Railway` | company `timezone` / `default_locale` have no settings-family write path yet |
| Attendance policy/settings | `read only` | `GET /api/settings/company-profile`, `GET /api/settings/locations`, `GET /api/hr/attendance/context` | `Railway` | read path exists for attendance enablement and resolved boundary, but no canonical company-level write API |
| Leave policy/settings | `missing` | DB functions exist, but no frontend-facing route family under `app/api` | `Railway` | write substrate exists in DB/RPC, but no canonical Railway settings route family yet |
| Attendance adjustment permission settings (`HR` / `manager`) | `missing` | no settings table or settings route; only operational `POST /api/hr/attendance/adjustments` | `Railway` | current permission is implicit in app role gate, not configurable as organization settings |

## Module Detail

### 1. Company Data

Current status:

- `read only`

Current runtime/path:

- [`GET /api/settings/company-profile`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/settings/company-profile/route.ts)

Current shape:

- reads from `companies` plus `company_settings`
- returns:
  - `company_name`
  - `company_legal_name`
  - `tax_id`
  - `address`
  - `timezone`
  - `default_locale`
  - `is_attendance_enabled`

Why it is not write-ready:

- there is no matching `PATCH /api/settings/company-profile`
- roadmap explicitly still describes settings as read-only in Sprint A:
  - [`adminos_v1_master_index.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/roadmap/adminos_v1_master_index.md:30)
  - [`adminos_v1_roadmap.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/roadmap/adminos_v1_roadmap.md:41)

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `PATCH /api/settings/company-profile`
- writable fields:
  - `company_legal_name`
  - `tax_id`
  - `address`
  - `timezone`
  - `default_locale`
  - `is_attendance_enabled`

### 2. Branch And GPS

Current status:

- `write ready`

Current runtime/path:

- read:
  - [`GET /api/settings/locations`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/settings/locations/route.ts)
- write:
  - [`POST /api/locations`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/locations/route.ts)
  - [`PATCH /api/locations/:id`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/locations/%5Bid%5D/route.ts)

What this currently proves:

- location rows can already be created and updated
- write payload already covers:
  - `name`
  - `address`
  - `latitude`
  - `longitude`
  - `checkin_radius_m`
  - `is_attendance_enabled`
  - `is_active`
  - `notes`

Why this is still not fully converged:

- canonical settings read family is `/api/settings/locations`
- actual write family is still `/api/locations`
- write helper is staging-only attendance phase runtime:
  - [`app/api/_attendance_phase1.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/_attendance_phase1.ts)

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `POST /api/settings/locations`
- `PATCH /api/settings/locations/:id`

### 3. Locale And Timezone

Current status:

- `read only`

Current runtime/path:

- company-level read via [`GET /api/settings/company-profile`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/settings/company-profile/route.ts:38)

Important distinction:

- employee-level locale/timezone writes already exist on employee detail patch:
  - [`PATCH /api/hr/employees/:id`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/%5Bid%5D/route.ts:157)
- but organization settings locale/timezone write does not exist yet

So for organization settings specifically:

- company `timezone` and `default_locale` are still read-only

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `PATCH /api/settings/company-profile`
- fields:
  - `timezone`
  - `default_locale`

### 4. Attendance Policy / Settings

Current status:

- `read only`

Current runtime/path:

- [`GET /api/settings/company-profile`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/settings/company-profile/route.ts)
- [`GET /api/settings/locations`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/settings/locations/route.ts)
- [`GET /api/hr/attendance/context`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/attendance/context/route.ts)

What exists today:

- company attendance enable flag can be read
- branch radius and enablement can be read
- resolved fallback model can be read through attendance context

What is missing for write:

- no canonical company-level write route for `attendance_boundary_settings`
- no canonical settings route for attendance source enablement or company default boundary

Related write-adjacent paths that exist but are not enough to call this module write-ready:

- [`PUT /api/attendance-sources/:id/locations`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/attendance-sources/%5Bid%5D/locations/route.ts)
- [`POST /api/locations`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/locations/route.ts)
- [`PATCH /api/locations/:id`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/locations/%5Bid%5D/route.ts)

Those help branch/source infrastructure, but they do not yet form one canonical attendance settings write family.

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `PATCH /api/settings/company-profile`
  - `is_attendance_enabled`
- `PATCH /api/settings/locations/:id`
  - `checkin_radius_m`
  - `is_attendance_enabled`

### 5. Leave Policy / Settings

Current status:

- `missing`

Current runtime/path:

- no frontend-facing leave policy settings route exists under `app/api`

What exists today:

- DB read/write substrate exists:
  - [`leave_policy_engine_read_write_layer_v1.sql`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/supabase/migrations/20260404224000_leave_policy_engine_read_write_layer_v1.sql)
  - [`leave_policy_engine_write_ops_v1.sql`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/supabase/migrations/20260404233000_leave_policy_engine_write_ops_v1.sql)
- examples:
  - `upsert_leave_policy_profile`
  - `upsert_leave_type`
  - `upsert_leave_entitlement_rule`
  - `disable_leave_type`
  - `delete_leave_entitlement_rule`

Why this is still `missing` for settings family:

- there is no Railway-owned route family that fronts these writes
- there is no current settings page contract under `app/api`

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `GET /api/hr/leave-policy/profile`
- `PATCH /api/hr/leave-policy/profile`
- or a tighter Phase 1 slice:
  - `GET /api/hr/leave-policy/profile`
  - `POST /api/hr/leave-policy/profile`

### 6. Attendance Adjustment Permission Settings (`HR` / `manager`)

Current status:

- `missing`

Current runtime/path:

- there is no settings route or settings table for this policy

What exists today instead:

- operational adjustment creation:
  - [`POST /api/hr/attendance/adjustments`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/attendance/adjustments/route.ts)
- permission is currently implicit through app write gate:
  - [`WRITE_ROLES` in `app/api/hr/_lib.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/_lib.ts:34)

Current effective behavior:

- `admin`-class writers can create adjustment requests
- `manager` is not in `WRITE_ROLES`
- there is no organization setting that toggles:
  - HR may adjust
  - manager may adjust

So this is not read-only. It is missing as a configurable settings module.

Canonical runtime:

- `Railway`

Minimal contract if implementation starts:

- `GET /api/settings/attendance-adjustment-permissions`
- `PATCH /api/settings/attendance-adjustment-permissions`
- minimal writable fields:
  - `hr_can_create_adjustment`
  - `manager_can_create_adjustment`

## Canonical Runtime Decision

For all organization settings modules in this audit, canonical frontend-facing runtime should be:

- `Railway`

Reason:

- selected context interpretation already lives in Railway app routes
- settings writes are permission-sensitive
- several modules combine company defaults plus branch overrides
- leave and attendance settings both involve business-rule orchestration that should not be split across frontend and DB direct calls

DB / RPC may remain the substrate for some modules, especially leave policy, but not the public contract owner.

## Best Next Write Verification Target

The best next real write-verification target is:

- `company profile`

Reason:

1. it already has a canonical read route:
   - `GET /api/settings/company-profile`
2. it is the clearest settings-family gap:
   - high-value read exists
   - matching write is completely absent
3. one minimal `PATCH` can unlock three audit areas at once:
   - company data
   - locale
   - timezone
4. it avoids route-family drift:
   - unlike locations, where write currently lives on `/api/locations`

## Minimal Recommended Next Contract

Recommended first write contract:

- `PATCH /api/settings/company-profile`

Minimal body:

```json
{
  "company_legal_name": "Lemma HR Taiwan Ltd.",
  "tax_id": "12345678",
  "address": "Taipei City ...",
  "timezone": "Asia/Taipei",
  "default_locale": "zh-TW",
  "is_attendance_enabled": true
}
```

Minimal response:

```json
{
  "schema_version": "settings.company_profile.update.v1",
  "data": {
    "company_profile": {
      "org_id": "....",
      "company_id": "....",
      "company_name": "Lemma HR",
      "company_legal_name": "Lemma HR Taiwan Ltd.",
      "tax_id": "12345678",
      "address": "Taipei City ...",
      "timezone": "Asia/Taipei",
      "default_locale": "zh-TW",
      "is_attendance_enabled": true
    }
  },
  "error": null
}
```

## Practical Conclusion

- company data: read exists, write missing
- branch and GPS: write exists, but not yet converged into canonical settings family
- locale and timezone: employee-level write exists, company settings write missing
- attendance policy/settings: read exists, write family not converged
- leave policy/settings: DB substrate exists, Railway settings API missing
- attendance adjustment permissions: configurable settings module is still missing entirely
