# Environment Governance v1

## Goal

Keep demo storytelling protected while enabling internal writable validation flows without turning one org into both showcase and test workspace.

## Canonical Terms

- `production`: live customer-facing environment
- `demo`: protected narrative environment for walkthroughs and showcase
- `staging-write`: writable internal validation environment
- `seed`: bootstrap data class, not a user-facing environment

## Org Strategy

The default model is:

- one dedicated demo org
- one dedicated staging-write org
- separate memberships for the same internal account when access to both is needed

This means `team@lemmaofficial.com` should be able to access:

- `lemma-demo`
- `lemma-staging-write`

But these must remain separate orgs with separate write policy.

## Governance Rules

### Demo

- Purpose: business narrative, product walkthrough, stable screenshots, stakeholder demos
- Mutation policy: read-only for normal product usage
- Reset policy: dedicated maintenance flow only
- Test policy: not a general smoke target

### Staging-write

- Purpose: QA, frontend acceptance, integration verification, temporary experiments
- Mutation policy: writable for approved internal roles
- Reset policy: allowed through runbook-driven reset/reseed
- Test policy: preferred target for validation and smoke tests

### Production

- Purpose: live customer operations
- Mutation policy: real writes only
- Reset policy: no seed-style reset
- Test policy: no exploratory data mutation

## Selected Context Rule

The system must not assume `memberships[0]` is the current context.

The long-term rule is:

- a user may hold multiple memberships
- the active workspace must be selected explicitly
- API access should validate against selected context, not incidental membership order

See `contracts/auth.me.v2.md` for the proposed contract baseline.

## Demo Protection Rule

Demo data must be protected by both process and technical policy:

- separate org
- separate seed layer
- separate reset runbook
- write-deny policy in later RLS/runtime implementation

## Staging-First Follow-Up

The next phase should add:

- selected context storage
- environment switch endpoint
- demo read-only guardrails
- demo reset and integrity verification helpers
