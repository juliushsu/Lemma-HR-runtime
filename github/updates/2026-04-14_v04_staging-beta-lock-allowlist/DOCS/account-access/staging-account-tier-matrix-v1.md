# Staging Account Tier Matrix v1

## Purpose

Provide a clear account-tier view for staging access that distinguishes:

- beta lock pass
- membership role
- writable allowed

## Definitions

### Beta Lock Pass

Whether the account may enter staging APIs at all.

### Membership Role

What scoped application role the user holds after entry.

### Writable Allowed

Whether the current rollout permits write operations in staging.

This is stricter than both beta lock pass and membership role.

## Current Matrix

| Account | Intended Use | Beta Lock Pass | Membership Role | Writable Allowed | Notes |
| --- | --- | --- | --- | --- | --- |
| `team@lemmaofficial.com` | Platform operator inspection | Yes | `super_admin` in sandbox test org | No | Passes beta lock but app-layer write remains blocked during rollout |
| `juliushsu@gmail.com` | Internal inspection | Yes | existing membership-based | No by default in this policy doc | Beta lock pass comes from internal flag migration |
| `staging.tester2@lemma.local` | Frontend smoke / canonical read verification | Not yet, target = Yes | keep existing membership | No | This pass should grant beta lock pass only |
| `demo.admin@lemma.local` | Demo review | Not part of staging allowlist by default | `admin` in demo scope | No for staging | Manage as demo-only account |

## Tier Policy

### Tier A: Read-Only Staging Validation

Accounts:

- `team@lemmaofficial.com`
- `juliushsu@gmail.com`
- `staging.tester2@lemma.local`

Policy:

- beta lock pass allowed
- read-path validation allowed
- write rollout not enabled

### Tier B: Writable Prepared

Accounts:

- none activated in this phase

Policy:

- candidates may be documented
- must not be enabled in this pass

### Tier C: Demo-Only

Accounts:

- `demo.admin@lemma.local`

Policy:

- separate from staging beta lock
- used for demo review only

## Single-Account Action In This Pass

Target account:

- `staging.tester2@lemma.local`

Action:

- enable beta lock pass
- preserve read-only posture
- avoid role elevation
- avoid writable enablement

## Validation Scope For `staging.tester2@lemma.local`

Allowed validation goals after beta lock pass:

- login and bearer token flow
- `GET /api/me`
- selected-context read behavior
- leave canonical route read-path checks that should return `200`
- other read-only canonical HR / legal endpoints consistent with current memberships

Not enabled by this pass:

- broad mutable staging acceptance
- admin write validation
- HR partner write validation
