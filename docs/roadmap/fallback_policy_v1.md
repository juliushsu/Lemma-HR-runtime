# Fallback Policy v1

## Environment Fallback Rules

## demo
- Primary: demo-scope canonical data (`environment_type='demo'`, `is_demo=true`).
- Allowed fallback: demo defaults for missing optional fields.
- Not allowed: production data fallback as primary source.

## staging
- Primary: staging deployment + scoped production/demo data per membership.
- Allowed fallback: field-level defaults when optional settings are missing.
- Not allowed: bypassing auth/scope or using mock payload as canonical output.

## production
- Primary: production-scope canonical data only.
- Allowed fallback: safe null/default for optional fields.
- Not allowed: demo seed data fallback.

## Completed Convergence (Current)
- HR employee list/detail canonical fields (including local/latin names)
- HR org chart canonical departments + members + manager linkage
- LC documents/cases list + detail
- Settings Sprint A read-only routes:
  - `GET /api/settings/company-profile`
  - `GET /api/settings/locations`

## Not Yet Fully Converged
- Settings write APIs (POST/PUT/PATCH)
- Shift / Leave / Payroll modules (skeleton only)
- Integration surfaces for passive triggers / ESG / CaCalLab

## ErrorState / DemoState Principles
- ErrorState
  - Use canonical envelope with explicit error code/message.
  - Do not silently switch to unrelated environment data.
  - Keep root-cause visibility for smoke and debugging.

- DemoState
  - Demo UI should read demo canonical seed first.
  - Demo defaults may fill optional fields, but must preserve scope integrity.
  - DemoState is not a substitute for production behavior; it is a scoped showcase.

## Operational Rules
- Never let mock payload be primary source after canonical API is available.
- Every fallback path must be deterministic and environment-scoped.
- Smoke reports should explicitly call out when fallback was used and why.
