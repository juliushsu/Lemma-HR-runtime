# Staging Beta Lock Allowlist v1

## Purpose

Define the minimum safe allowlist strategy for staging access without opening writable access broadly.

This document separates three concepts that must not be merged:

- `beta lock pass`
- `membership role`
- `writable allowed`

## Core Rule

Staging access is controlled in layers.

### 1) Beta Lock Pass

This is the entry gate for staging API access.

A user may pass staging beta lock only if at least one of the following is true:

- `is_test_user = true`
- `is_internal_user = true`
- `is_portal_user = true`
- `users.security_role = 'org_super_admin'`

This layer answers only:

- can the user reach staging APIs at all

It does not answer:

- what org/company they can see
- whether they can write

## 2) Membership Role

Memberships determine scoped access after beta lock is passed.

Typical examples:

- `viewer`: read-oriented
- `manager`: broader read scope depending on resolver
- `admin` / `super_admin`: admin-level scope

This layer answers:

- which org/company/environment the user belongs to
- what scope they can read
- what role family they hold

It does not, by itself, guarantee writable access in staging rollout.

## 3) Writable Allowed

Writable access is a stricter layer than both beta lock and membership.

For staging rollout, writable should be treated as an explicit rollout permission, not something implied by beta lock pass.

Current special rule:

- `team@lemmaofficial.com` may pass beta lock and inspect staging, but remains non-writable in app-layer enforcement during this rollout phase

Therefore:

- `beta lock pass = true` does not imply write
- `membership role = admin/super_admin` does not automatically imply write during rollout

## Minimum Safe Strategy

Current policy target:

- do not expand staging writable population
- do not open HR partner writable access
- do not convert smoke/test users into broad internal users

Recommended minimum allowlist tiers:

### Tier A: Read-Only Staging Validation

Use for:

- frontend integration validation
- canonical route smoke
- selected-context read path verification
- leave canonical read verification

Recommended account set:

- `team@lemmaofficial.com`
- `juliushsu@gmail.com`
- `staging.tester2@lemma.local`

Rules:

- may pass beta lock
- must keep read-only effective behavior
- must not be used to validate general writable rollout

### Tier B: Writable Prepared But Not Enabled

Use for:

- future rollout planning only

Rules:

- document candidates separately
- do not activate in current phase

Current recommendation:

- no new writable accounts enabled in this pass

### Tier C: Demo-Only Review

Use for:

- narrative walkthrough
- protected demo validation

Rules:

- managed separately from staging beta lock
- should not be treated as staging allowlist members by default

## Single-Account Change In This Pass

This pass handles only:

- `staging.tester2@lemma.local`

Desired outcome:

- pass staging beta lock
- keep effective read-only usage
- do not add internal-wide privileges
- do not broaden any other allowlist entry

## Recommended Implementation

For `staging.tester2@lemma.local`:

- mark the user as `is_test = true`
- keep `security_role = 'tester'`
- keep existing membership as-is unless scope correction is separately required
- do not elevate to `internal`
- do not elevate to `org_super_admin`
- do not add writable role changes in this migration

## Non-Goals

- no broad staging allowlist expansion
- no HR partner writable enablement
- no demo/write convergence
- no change to app-layer write blocks

## Review Checklist

After rollout, confirm:

1. `staging.tester2@lemma.local` no longer receives `BETA_LOCK_FORBIDDEN`
2. read routes return `200`
3. write routes still do not become approved writable validation routes for this account
4. no other account behavior changes
