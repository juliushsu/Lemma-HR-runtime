# Selected Context Runtime Staging Smoke v1

## Goal

Verify the staging-first selected context rollout without changing production behavior.

## Preconditions

- staging runtime only
- authenticated bearer token available
- user with one membership
- user with multiple memberships
- demo membership remains read-only
- `team@lemmaofficial.com` remains non-writable

## Smoke 1: Single Membership

1. Call `GET /api/me`
2. Expect `schema_version = auth.me.v2` in staging
3. Expect exactly one `available_contexts[]`
4. Expect `current_context.membership_id` to match the only membership
5. Expect `current_org/current_company/environment_type` to mirror `current_context`

## Smoke 2: Multiple Memberships

1. Call `GET /api/me`
2. Expect more than one `available_contexts[]`
3. Confirm frontend never needs `memberships[0]` to identify active workspace
4. Confirm `current_context` exists even when no explicit cookie has been set

## Smoke 3: Context Switch

1. Call `POST /api/session/context` with a valid `membership_id`
2. Expect `200`
3. Expect `Set-Cookie` for `lemma_selected_membership_id`
4. Re-call `GET /api/me`
5. Expect returned `current_context.membership_id` to match the selected membership

## Smoke 4: Invalid Membership

1. Call `POST /api/session/context` with a membership not owned by the current user
2. Expect `404`
3. Expect error code `MEMBERSHIP_NOT_FOUND`

## Smoke 5: Demo Write Deny

1. Switch into a demo context
2. Attempt a known write endpoint in that same scope
3. Expect `403`
4. Confirm write is denied even if membership role is elevated

## Smoke 6: Team Account Writable Lock

1. Authenticate as `team@lemmaofficial.com`
2. Call `GET /api/me`
3. Confirm `available_contexts[].writable = false` for all contexts
4. Attempt `POST /api/session/context` toward a would-be writable staging membership
5. Expect `403` if rollout tries to elevate writable access

## Smoke 7: Staging Write Allow

1. Authenticate as a non-team staging admin account
2. Switch into a sandbox write context
3. Call a staging write endpoint with no explicit `org_id/company_id`
4. Expect server to resolve scope from selected context
5. Expect write success when membership role and scope allow it

## Smoke 8: Selected Context Conflict

1. Switch into one context
2. Call a write endpoint with explicit `org_id/company_id/environment_type` from a different context
3. Expect `403` or scope resolution failure
4. Confirm server session wins over browser-side assumptions
