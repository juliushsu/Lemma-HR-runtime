# Demo Reset v1

## Purpose

Reset the protected demo org back to a known narrative baseline without using general-purpose smoke or staging write flows.

## Principles

- Demo reset is maintenance-only.
- Demo reset must be auditable.
- Demo reset must replay protected demo seeds in a controlled order.
- Demo reset must not be mixed with staging-write validation.

## Recommended Flow

1. Confirm target org is the demo org, not staging-write.
2. Freeze ad hoc test execution against the demo org.
3. Run base seeds required by the demo dependency graph.
4. Replay demo seeds in documented order.
5. Run demo integrity verification.
6. Record reset timestamp, actor, and reason.

## Seed Order

1. `base` dependency seeds
2. demo HR baseline seeds
3. demo attendance / onboarding / GPS seeds
4. demo LC+ narrative seeds
5. demo portal narrative seeds when moved or added

## Do Not

- Do not use staging smoke scripts on the demo org.
- Do not patch demo data manually unless the reset runbook is also updated.
- Do not treat demo reset as a generic truncate-and-seed workflow.

## Future Automation

The next implementation phase should provide:

- `reset_demo_org_v1(...)`
- `verify_demo_org_integrity_v1(...)`

But those functions are not introduced in this governance-only pass.
