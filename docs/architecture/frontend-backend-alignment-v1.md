# Frontend Backend Alignment v1

## Purpose

This document defines the minimum safe contract between frontend workspace switching and backend scope resolution for the staging-first selected context rollout.

## Problem Being Solved

The frontend currently carries risk from:

- `memberships[0]` assumptions
- browser-side override logic such as `sessionStorage`
- UI environment labels that may drift from backend scope reality

The alignment rule is simple:

- frontend may display available choices
- backend remains authoritative for the active context

## Frontend Can Trust

From `GET /api/me v2`, frontend may trust:

- `data.available_contexts`
- `data.current_context`
- `data.current_org`
- `data.current_company`
- `data.environment_type`
- `data.current_context.writable`

From `POST /api/session/context`, frontend may trust:

- `data.current_context`

## Frontend Must Not Derive

Frontend must not derive active context from:

- `memberships[0]`
- `current_org` alone
- `current_company` alone
- `environment_type` alone
- local `sessionStorage`
- UI tab state or previously clicked workspace button

## Source Relationship

The only approved relationship is:

`current_context`
-> resolves `current_org`
-> resolves `current_company`
-> mirrors `environment_type`

This means:

- `current_context` is primary
- `current_org/current_company/environment_type` are resolved convenience fields
- if any sibling field disagrees with `current_context`, `current_context` wins

## Why `memberships[0]` Is Not Safe

- membership order is incidental, not semantic
- multi-membership users break first-item assumptions
- wrong-write risk appears when UI and backend choose different memberships
- audit logs cannot prove user intent from unordered memberships

## Context Switch Rule

### Canonical Rule

After `POST /api/session/context` succeeds:

- frontend does not need to send an extra context header by default
- backend resolves future requests using server-side selected context

### Single Source of Truth

The server-owned session is the only source of truth for current workspace selection.

Frontend may cache for UX, but cache is advisory only.

## Header Rule

Default rollout rule:

- no required context header

If a temporary staging debug header is ever used, it must be treated as non-canonical and lower priority than server session.

Priority order:

1. server-owned selected context session
2. authenticated membership validation on the server
3. optional staging debug header
4. frontend local storage or `sessionStorage`

## Readdy Integration Checklist

Readdy should:

- read workspace options from `available_contexts`
- render active workspace from `current_context`
- call `POST /api/session/context` when the user switches workspace
- re-fetch `GET /api/me v2` after switching
- use `current_context.writable` to gate write-oriented UI affordances

Readdy should not:

- infer active workspace from `memberships[0]`
- persist authoritative context in browser storage only
- assume demo UI means backend is actually in demo context

## Staging-First Constraint

- demo remains read-only
- `team@lemmaofficial.com` remains non-writable until selected context contract and enforcement are validated
- production remains unchanged during this alignment phase
