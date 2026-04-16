# Selected Context Decisions v1

## Decision Summary

Lemma HR+ will adopt:

- dual org strategy
- multiple memberships per internal user when needed
- explicit selected context

And will reject:

- single-org mixed demo/write strategy
- implicit current workspace based on `memberships[0]`

## Why Dual Org + Multiple Memberships

### Demo and writable staging have different jobs

- `lemma-demo` exists to preserve narrative quality
- `lemma-staging-write` exists to allow mutation, QA, and acceptance testing

Trying to make one org satisfy both jobs creates constant policy conflict.

### Read-only demo must be technically protectable

If demo and staging-write are the same org, write protection becomes a soft process rule instead of a hard system boundary.

### Memberships are the right place to express access breadth

One internal user may need to inspect demo and also work in staging. That is an access-model issue, not a reason to collapse environments.

## Why We Cannot Rely on `memberships[0]`

### Ordering is incidental

Membership ordering depends on insert order or query order, not user intent.

### It does not scale to multi-context users

Once a user has both demo and staging memberships, `memberships[0]` becomes ambiguous and dangerous.

### It creates wrong-write risk

A frontend may render one environment while the backend resolves writes against another if context is inferred differently in different places.

### It hides audit intent

The system should be able to say which membership the user actively selected when a read or write occurred.

## Rollout Decision

- selected context is introduced in staging first
- demo remains protected and read-only
- writable membership expansion happens only after contract and helper alignment are complete
- production remains unchanged during this phase

## Design Principles

- reversible
- auditable
- additive
- rollout-friendly
- explicit over implicit
