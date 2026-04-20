# API Debug Drawer Visibility Policy v1

Status: internal visibility governance rule

Purpose:

- define who is allowed to see the API Debug Drawer
- keep the drawer limited to internal debugging and validation use
- prevent the drawer from becoming an accidental general-user or public-facing feature

This document is a visibility policy.
It does not implement runtime behavior in this round.

## 1. Policy Goal

The API Debug Drawer exists to help privileged internal users inspect:

- current context
- last API request
- identity interpretation
- scope interpretation
- canonical error state

Because it exposes sensitive debugging information, it must not be visible to normal product users by default.

## 2. Allowed User Classes

### 2.1 System Governance Roles

Phase 1 allowed governance roles:

- `owner`
- `super_admin`

These roles may see the drawer because they are responsible for:

- runtime governance
- cross-flow debugging
- scope and identity validation
- staging/sandbox integration review

### 2.2 Test / QA Accounts

Phase 1 allowed internal testing classes:

- designated test mode accounts
- designated internal QA accounts
- explicitly approved sandbox or staging validation accounts

These accounts are allowed only when they are intentionally provisioned for internal validation.

Examples of qualifying account types:

- internal staging smoke account
- sandbox pilot validation account
- internal QA walkthrough account

This policy is account-class based, not broad role-based exposure for all staff.

## 3. Environment Visibility

### 3.1 Sandbox Visibility

Sandbox visibility is allowed in Phase 1 for approved internal accounts.

Reason:

- sandbox is a controlled validation environment
- identity/scope interpretation often needs direct inspection there
- the drawer supports internal mutation debugging without exposing a broader system

### 3.2 Staging Visibility

Staging visibility is allowed in Phase 1 for approved internal accounts.

Reason:

- staging is the primary internal validation environment
- selected-context debugging and runtime ownership checks are staging-first concerns
- the drawer is useful for QA, owner review, and convergence validation

### 3.3 Production Visibility

Phase 1 default policy:

- do not expose the API Debug Drawer to general production traffic
- do not treat production as an automatic allowed environment

If any future production visibility is ever considered, it must be:

- explicitly re-approved
- limited to tightly controlled internal accounts
- documented by a stricter follow-up policy

## 4. Phase 1 Minimal Rule

Phase 1 visibility rule is intentionally simple:

- visible only to `owner` and `super_admin`
- visible to explicitly approved test / QA accounts
- allowed in sandbox and staging internal validation contexts
- hidden from normal employee, manager, admin, and public-facing end users

This is the minimum safe allowlist for first rollout.

## 5. Non-Goals

This policy does not do the following:

- open the drawer to general formal production accounts
- open the drawer to all authenticated users
- make the drawer a general-purpose support console
- replace formal RBAC or environment governance documents

Direct non-goal:

- the drawer is not for general official production users

## 6. Recommended Interpretation Rules

To avoid ambiguity, the visibility decision should prefer:

1. explicit internal allowlist
2. governance role check
3. environment check

Recommended meaning:

- role alone is not sufficient if the account is not part of the intended internal validation population
- environment alone is not sufficient if the account is not allowed
- the drawer should appear only when both user class and environment intent are acceptable

## 7. Future Stricter Policy

If a stricter policy is needed later, the next version may add:

- explicit account allowlist by email or user id
- environment-specific deny rules
- feature-flag gating by deployment target
- module-level visibility restrictions
- temporary access expiry for QA accounts

Possible stricter future direction:

- sandbox and staging only by default
- production hidden entirely unless a named emergency/internal override is granted
- QA visibility granted only to enumerated accounts instead of broad account classes

## 8. Decision Summary

The API Debug Drawer should be visible only to:

- `owner`
- `super_admin`
- approved internal test / QA accounts

Phase 1 visibility is allowed in:

- `sandbox`
- `staging`

The drawer should not be opened to:

- general formal production accounts
- normal employee users
- ordinary admin users who are not part of internal validation

This keeps the drawer aligned with its actual purpose:

- internal API debugging
- convergence validation
- scope and identity inspection
