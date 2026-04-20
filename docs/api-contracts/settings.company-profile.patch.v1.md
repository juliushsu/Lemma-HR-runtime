# `PATCH /api/settings/company-profile` Contract

## 1. Endpoint Metadata

- method: `PATCH`
- path: `/api/settings/company-profile`
- schema version: `settings.company_profile.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required
- canonical read counterpart:
  - `GET /api/settings/company-profile`
  - schema version: `settings.company_profile.v1`

## 2. Canonical Runtime Rule

This is an organization settings write route.

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- selected context is resolved server-side
- current company scope comes from selected context plus authenticated JWT
- frontend must not send `org_id`, `company_id`, `branch_id`, or `environment_type` as truth

## 3. Phase 1 Write Scope

This route updates one company profile inside the selected company scope only.

Phase 1 scope rule:

1. resolve selected context from server-side membership selection
2. require writable company scope
3. resolve target company from selected context only
4. reject any attempt to treat body-sent scope fields as authority

## 4. Allowed Roles

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Not allowed in Phase 1:

- `manager`
- `operator`
- `viewer`

Reason:

- current app write governance already limits writable organization scope to those roles
- company profile is organization-level configuration, not team-level configuration

## 5. Canonical Data Targets

This route writes across two canonical data targets:

- `public.companies`
  - `name`
- `public.company_settings`
  - `company_legal_name`
  - `tax_id`
  - `address`
  - `timezone`
  - `default_locale`
  - `is_attendance_enabled`

Phase 1 write interpretation:

- `company_name` maps to `companies.name`
- all other writable settings map to `company_settings`

## 6. Writable Fields

Phase 1 allows these body fields:

| Field | Type | Required | Write target | Notes |
| --- | --- | --- | --- | --- |
| `company_name` | `string` | no | `companies.name` | trimmed; empty string invalid |
| `company_legal_name` | `string` | no | `company_settings.company_legal_name` | trimmed; empty string invalid |
| `tax_id` | `string \| null` | no | `company_settings.tax_id` | trimmed; empty string becomes `null` |
| `registration_no` | not supported | n/a | n/a | Phase 1 schema uses `tax_id`; `registration_no` must be rejected or ignored by contract consumers |
| `address` | `string \| null` | no | `company_settings.address` | trimmed; empty string becomes `null` |
| `timezone` | `string` | no | `company_settings.timezone` | trimmed; empty string invalid |
| `default_locale` | `string` | no | `company_settings.default_locale` | trimmed; empty string invalid |
| `is_attendance_enabled` | `boolean` | no | `company_settings.is_attendance_enabled` | explicit boolean only |

At least one writable field must be provided.

## 7. Validation Rules

Phase 1 minimal validation:

### Common

- request body must be valid JSON
- at least one supported writable field must be present
- unsupported keys may be ignored, but must not be treated as authority inputs

### String fields

- `company_name`: trimmed, must not become empty string
- `company_legal_name`: trimmed, must not become empty string
- `timezone`: trimmed, must not become empty string
- `default_locale`: trimmed, must not become empty string

### Nullable string fields

- `tax_id`: trimmed; empty string normalizes to `null`
- `address`: trimmed; empty string normalizes to `null`

### Boolean field

- `is_attendance_enabled` must be a boolean when present

Phase 1 intentionally does not add:

- full timezone registry validation
- locale allowlist validation
- country-specific tax-id format validation

## 8. Write Behavior

Canonical Phase 1 behavior:

1. resolve actor from JWT
2. resolve selected context and writable company scope
3. load current `companies` row in scope
4. upsert or update `company_settings` row in the same scope
5. update `companies.name` if `company_name` is provided
6. return one canonical `company_profile` payload

Consistency rule:

- route implementation should avoid partial write where `companies.name` updates but `company_settings` fails, or vice versa
- if implementation spans multiple write targets, it should prefer transaction-minded apply behavior

## 9. Success Response

Success response must preserve the canonical company profile view model.

### Success example

```json
{
  "schema_version": "settings.company_profile.update.v1",
  "data": {
    "org_id": "11000000-0000-0000-0000-000000000001",
    "company_id": "22000000-0000-0000-0000-000000000001",
    "company_name": "Lemma HR",
    "company_legal_name": "Lemma HR Taiwan Ltd.",
    "tax_id": "12345678",
    "address": "Taipei City ...",
    "timezone": "Asia/Taipei",
    "default_locale": "zh-TW",
    "is_attendance_enabled": true,
    "company_profile": {
      "org_id": "11000000-0000-0000-0000-000000000001",
      "company_id": "22000000-0000-0000-0000-000000000001",
      "company_name": "Lemma HR",
      "company_legal_name": "Lemma HR Taiwan Ltd.",
      "tax_id": "12345678",
      "address": "Taipei City ...",
      "timezone": "Asia/Taipei",
      "default_locale": "zh-TW",
      "is_attendance_enabled": true
    }
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-20T12:00:00.000Z"
  },
  "error": null
}
```

### Guaranteed success fields

- `data.org_id`
- `data.company_id`
- `data.company_name`
- `data.company_legal_name`
- `data.tax_id`
- `data.address`
- `data.timezone`
- `data.default_locale`
- `data.is_attendance_enabled`
- `data.company_profile`

## 10. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SCOPE_FORBIDDEN` | selected context is not writable by current actor |
| `400` | `INVALID_REQUEST` | invalid JSON, no writable field, or invalid field type/value |
| `404` | `COMPANY_NOT_FOUND` | selected company cannot be resolved in current scope |
| `500` | `CONFIG_MISSING` | runtime dependency missing, if applicable |
| `500` | `INTERNAL_ERROR` | failed to update `companies` or `company_settings` |

## 11. Non-goals

This Phase 1 contract does not do:

- locations write
- attendance boundary write
- leave policy write
- attendance adjustment permission settings
- multi-company bulk update
- portal write path
