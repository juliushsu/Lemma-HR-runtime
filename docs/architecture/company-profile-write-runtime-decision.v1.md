# Company Profile Write Runtime Decision v1

## Purpose

Define the canonical runtime for company profile write operations.

This decision covers:

- `PATCH /api/settings/company-profile`

## Decision

Canonical frontend-facing runtime for company profile write is:

- `Railway`

## Why Railway

Company profile write depends on:

1. authenticated JWT actor resolution
2. selected-context company scope resolution
3. writable organization-role enforcement
4. controlled write across:
   - `public.companies`
   - `public.company_settings`
5. canonical response shaping aligned with the existing read route

These are app-runtime orchestration concerns and should stay in Railway.

## Why Not Supabase Edge

This is not a proxy-only surface.

It should not be owned by Supabase Edge because:

- selected-context interpretation already lives in app runtime
- write role enforcement must align with current app route role gates
- the route spans more than one data target and should not split logic between multiple runtime families

## Why Not DB/RPC As Frontend Runtime

`DB / RPC / direct Supabase client` may remain a future internal substrate for atomic apply, but it should not own the public contract.

Reason:

- frontend-facing contract ownership should remain in one Railway route family
- selected-context interpretation should not split between frontend, DB, and app route

## Scope Decision

Phase 1 scope source is:

- selected context + JWT only

Not allowed:

- frontend-sent `company_id`
- frontend-sent `org_id`
- frontend-sent `environment_type`

The selected company context is the only canonical target company for this route.

## Role Decision

Phase 1 write roles:

- `owner`
- `super_admin`
- `org_super_admin`
- `admin`

Managers are intentionally excluded because current app write governance does not include `manager` in writable organization settings scope.

## Data Ownership Decision

Company profile write spans two canonical targets:

- `public.companies`
  - `name`
- `public.company_settings`
  - `company_legal_name`
  - `tax_id`
  - `address`
  - `timezone`
  - `default_locale`
  - `is_attendance_enabled`

Phase 1 interpretation:

- `company_name` is part of canonical company profile and may be updated in `companies.name`
- `registration_no` is not introduced because current Phase 1 schema uses `tax_id`

## Consistency Decision

Because this write touches more than one data target, implementation should prefer transaction-minded apply behavior.

That means the runtime should avoid:

- `companies.name` updated but `company_settings` failed
- `company_settings` updated but `companies.name` failed

If the route is implemented without a DB function in Phase 1, it should still be treated as one logical write path and hardened toward atomic behavior in the next iteration if needed.

## Response Shape Decision

The write response should preserve the same company profile view model used by the read route:

- flattened aliases for compatibility
- nested `data.company_profile`

This keeps frontend consumption stable between read and write response shapes.

## Temporary Compatibility

There is no separate MVP write family for company profile.

Canonical target is directly:

- `/api/settings/company-profile`

This avoids introducing a second organization settings write family before convergence begins.

## Non-goals

This runtime decision does not include:

- locations family write
- leave policy write
- attendance adjustment permission settings
- portal write path
- bulk settings update
