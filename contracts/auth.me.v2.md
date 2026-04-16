# auth.me.v2

## Purpose

Define the contract baseline for explicit environment switching and selected context. This is a documentation-first contract and does not imply that runtime implementation is complete yet.

## Why v2 Exists

`auth.me.v1` is sufficient for a single effective membership, but it is not a safe long-term contract once one user can access both:

- `lemma-demo`
- `lemma-staging-write`

The contract must stop implying that the first membership is the active context.

## Response Shape

```json
{
  "schema_version": "auth.me.v2",
  "data": {
    "user": {},
    "memberships": [],
    "available_contexts": [],
    "current_context": null,
    "current_org": null,
    "current_company": null,
    "locale": "en",
    "environment_type": "production"
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

## Minimum Required Fields

- `data.user.id`
- `data.user.email`
- `data.memberships[]`
- `data.available_contexts[]`
- `data.current_context`
- `data.current_org`
- `data.current_company`
- `data.locale`
- `data.environment_type`

## Context Object

```json
{
  "membership_id": "uuid",
  "org_id": "uuid",
  "org_slug": "lemma-demo",
  "org_name": "Lemma Demo",
  "company_id": "uuid",
  "company_name": "Lemma Demo Company",
  "role": "viewer",
  "scope_type": "company",
  "environment_type": "demo",
  "access_mode": "read_only_demo",
  "writable": false,
  "is_default": false
}
```

## Context Object Field Notes

- `membership_id`: stable selection key for environment switching
- `org_slug`: frontend-safe org label and switch target reference
- `access_mode`: policy label, not only display text
- `writable`: frontend hint only; backend policy remains authoritative
- `is_default`: indicates preferred landing context, not forced context

## Membership Object

`memberships[]` may remain closer to the raw table shape than `available_contexts[]`, but must at minimum include:

```json
{
  "id": "uuid",
  "org_id": "uuid",
  "company_id": "uuid",
  "branch_id": null,
  "role": "viewer",
  "scope_type": "company",
  "environment_type": "demo",
  "is_default": false
}
```

## Required Rules

- `memberships` is the raw list of granted memberships
- `available_contexts` is the normalized list the frontend may switch into
- `current_context` is the authoritative runtime context
- `current_org` and `current_company` should reflect `current_context`, not incidental ordering
- `environment_type` should reflect `current_context`
- `current_context.membership_id` must be one of the user's memberships
- `current_context` must be null only when the user has no valid selectable context
- `current_org` and `current_company` must be derived from the selected context, not from separate fallback ordering

## Source of Truth Relationship

- `current_context` is the source of truth
- `current_org` is a resolved view derived from `current_context.org_id`
- `current_company` is a resolved view derived from `current_context.company_id`
- `environment_type` is a convenience mirror derived from `current_context.environment_type`

Frontend should trust this direction only:

`current_context -> current_org/current_company/environment_type`

Frontend should not reverse-derive `current_context` from those sibling fields.

## Backward Compatibility

- `auth.me.v1` may stay available during rollout
- `auth.me.v2` should be introduced staging-first
- frontend adapters should prefer `current_context` when present
- if both `auth.me.v1` and `auth.me.v2` are temporarily exposed, v2 wins for workspace switching behavior

## Compatibility Guidance

- Existing clients may continue consuming `auth.me.v1`
- New environment-switch UI should target `auth.me.v2`
- No client should assume `memberships[0]` is the active workspace

## Proposed Companion Endpoint

### `POST /api/session/context`

Request:

```json
{
  "membership_id": "uuid"
}
```

Response:

```json
{
  "schema_version": "auth.session.context.v1",
  "data": {
    "current_context": {
      "membership_id": "uuid",
      "org_id": "uuid",
      "company_id": "uuid",
      "environment_type": "sandbox",
      "access_mode": "sandbox_write",
      "writable": true
    }
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

## Readdy Mapping Guidance

Readdy should render workspace switching from:

- `data.available_contexts`
- `data.current_context`

Readdy should not infer current workspace from:

- `data.memberships[0]`
- `data.current_org` alone
- `data.environment_type` alone

## Transport Rule

For the staging-first selected context rollout, subsequent API requests do not require an extra context header by default.

Preferred rule:

- authentication continues via bearer token
- selected context is stored server-side or in a signed server-controlled session cookie
- backend resolves the active membership from that server-side selection

Optional debug or transition headers may exist in staging, but must not become the canonical client contract.
