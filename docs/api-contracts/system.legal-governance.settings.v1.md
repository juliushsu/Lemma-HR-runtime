# `GET / PATCH /api/system/legal-governance/settings` Contract

## 1. Endpoint Metadata

- methods:
  - `GET`
  - `PATCH`
- path: `/api/system/legal-governance/settings`
- read schema version: `system.legal_governance.settings.v1`
- write schema version: `system.legal_governance.settings.update.v1`
- auth requirement: `Authorization: Bearer <JWT>` required

## 2. Ownership Rule

This family is:

- `system-level`
- `platform-owned`
- not customer-owned

Customers must not directly modify these settings.

This family exists for platform governance only.

## 3. Canonical Runtime Rule

Canonical frontend-facing runtime must be:

- `Railway`

Canonical scope interpretation:

- actor is resolved from JWT
- access is enforced by platform/system governance role gate
- company selected context is not the authority for write permission here
- this route must not be exposed as a customer configuration toggle surface

## 4. Phase 1 Managed Fields

Phase 1 managed fields should include at least:

- `active_model`
- `fallback_model`
- `jurisdiction_update_mode`
- `auto_scan_enabled`
- `scan_frequency`
- `risk_thresholds`
- `provider_configuration_ref`
- `modifiable_by_roles`

### Suggested field notes

| Field | Type | Notes |
| --- | --- | --- |
| `active_model` | `string` | active legal comparison model |
| `fallback_model` | `string` | failover model reference |
| `jurisdiction_update_mode` | `string` | how legal updates are refreshed |
| `auto_scan_enabled` | `boolean` | platform-controlled scanner toggle |
| `scan_frequency` | `string` | scheduled frequency label |
| `risk_thresholds` | `object` | threshold config for warning surfacing |
| `provider_configuration_ref` | `string` | reference only; not raw secret |
| `modifiable_by_roles` | `array<string>` | system-level role allowlist |

Allowed `jurisdiction_update_mode` values:

- `manual_curated`
- `scheduled_curated`
- `hybrid`

Allowed `scan_frequency` examples:

- `daily`
- `weekly`
- `manual_only`

## 5. `GET /api/system/legal-governance/settings`

### Purpose

Return platform-managed legal governance settings for internal/system governance use.

### Success example

```json
{
  "schema_version": "system.legal_governance.settings.v1",
  "data": {
    "active_model": "legal-governance-primary-v1",
    "fallback_model": "legal-governance-fallback-v1",
    "jurisdiction_update_mode": "scheduled_curated",
    "auto_scan_enabled": true,
    "scan_frequency": "daily",
    "risk_thresholds": {
      "medium_requires_check": true,
      "high_requires_human_review": true,
      "critical_blocks_auto_adoption": true
    },
    "provider_configuration_ref": "legal-provider-config/default",
    "modifiable_by_roles": [
      "platform_owner",
      "system_governance_admin"
    ]
  },
  "meta": {
    "request_id": "11111111-1111-1111-1111-111111111111",
    "timestamp": "2026-04-21T12:00:00.000Z"
  },
  "error": null
}
```

## 6. `PATCH /api/system/legal-governance/settings`

### Purpose

Update platform-managed legal governance settings.

### Writable fields

Request body may include:

- `active_model`
- `fallback_model`
- `jurisdiction_update_mode`
- `auto_scan_enabled`
- `scan_frequency`
- `risk_thresholds`
- `provider_configuration_ref`

At least one writable field must be provided.

### Validation rules

- body must be valid JSON
- `active_model` and `fallback_model` must be recognized model references
- `jurisdiction_update_mode` must be one of:
  - `manual_curated`
  - `scheduled_curated`
  - `hybrid`
- `auto_scan_enabled` must be boolean
- `scan_frequency` must be a supported schedule label
- `provider_configuration_ref` must be a configuration reference, not raw API keys
- secrets must not be returned in response payloads

### Phase 1 write behavior

Canonical behavior:

1. resolve actor from JWT
2. confirm actor is in a platform governance role
3. update system-managed legal governance settings
4. return the canonical sanitized settings payload

## 7. Error Matrix

| HTTP | Code | Meaning |
| --- | --- | --- |
| `401` | `UNAUTHORIZED` | missing or invalid bearer token |
| `403` | `SYSTEM_SCOPE_FORBIDDEN` | actor is not allowed to manage system legal settings |
| `400` | `INVALID_REQUEST` | invalid JSON or invalid field value |
| `500` | `CONFIG_MISSING` | required platform governance substrate missing |
| `500` | `INTERNAL_ERROR` | failed to load or update settings |

## 8. Non-goals

This contract does not do:

- customer model switching
- provider key exposure
- direct customer policy overwrite
- legal document analysis result retrieval
- governance-check adoption actions
