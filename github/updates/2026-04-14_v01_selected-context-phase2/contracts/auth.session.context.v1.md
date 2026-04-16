# auth.session.context.v1

## Purpose

Define the contract for explicitly selecting the current workspace context in staging-first rollout.

## Endpoint

- `POST /api/session/context`

## Request

```json
{
  "membership_id": "uuid"
}
```

## Request Rules

- `membership_id` is required
- the target membership must belong to the authenticated user
- selecting a `demo` membership does not grant write access
- selecting a membership updates current session context only

## Success Response

```json
{
  "schema_version": "auth.session.context.v1",
  "data": {
    "current_context": {
      "membership_id": "uuid",
      "org_id": "uuid",
      "org_slug": "lemma-staging-write",
      "org_name": "Lemma Staging Write",
      "company_id": "uuid",
      "company_name": "Lemma Staging Company",
      "role": "admin",
      "scope_type": "company",
      "environment_type": "sandbox",
      "access_mode": "sandbox_write",
      "writable": true,
      "is_default": false
    }
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

## Failure Examples

### Unknown Membership

```json
{
  "schema_version": "auth.session.context.v1",
  "data": {
    "current_context": null
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": {
    "code": "MEMBERSHIP_NOT_FOUND",
    "message": "The requested membership is not available to the current user.",
    "details": null
  }
}
```

### Forbidden Membership

```json
{
  "schema_version": "auth.session.context.v1",
  "data": {
    "current_context": null
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": {
    "code": "CONTEXT_SWITCH_FORBIDDEN",
    "message": "The requested workspace cannot be selected in the current rollout stage.",
    "details": null
  }
}
```

## Staging-First Notes

- This contract is for staging-first rollout only
- production should remain unchanged until selected context behavior is validated
- `team@lemmaofficial.com` should not be granted writable staging membership until contract and policy alignment are complete
