## Source Record

### Family Owner

- owner: `AI-assisted legal governance layer`
- source_repo: `Lemma-HR-runtime`
- deploy_target: `Railway staging`
- deploy_method: `CLI upload`
- deployment_id: `c3b57ce3-4a7f-4a2d-aee3-5f56878c3575`
- last_verified_at: `2026-04-21`

### Canonical Runtime Families

#### System settings family

- intended source path:
  - `app/api/system/legal-governance/settings/route.ts`
- contract doc:
  - `docs/api-contracts/system.legal-governance.settings.v1.md`
- schema versions:
  - read: `system.legal_governance.settings.v1`
  - write: `system.legal_governance.settings.update.v1`

#### Legal updates family

- intended source path:
  - `app/api/legal/updates/route.ts`
  - `app/api/legal/updates/[id]/route.ts`
- contract doc:
  - `docs/api-contracts/legal.governance.v1.md`
- schema versions:
  - list: `legal.update.list.v1`
  - detail: `legal.update.detail.v1`

#### Governance checks family

- source path:
  - `app/api/legal/governance-checks/route.ts`
  - `app/api/legal/governance-checks/[id]/route.ts`
  - `app/api/legal/governance-checks/[id]/acknowledge-warning/route.ts`
  - `app/api/legal/governance-checks/_actions.ts`
- contract doc:
  - `docs/api-contracts/legal.governance.v1.md`
- schema versions:
  - list: `legal.governance_checks.list.v1`
  - detail: `legal.governance_checks.detail.v1`
  - mutation: `legal.governance.decision.v1`
- db substrate:
  - table: `public.legal_governance_checks`
  - table: `public.legal_governance_decisions`
  - migration: `supabase/migrations/20260422113000_legal_governance_checks_phase1_read_substrate.sql`
  - migration: `supabase/migrations/20260422143000_legal_governance_acknowledge_warning.sql`
  - staging seed: `supabase/seeds/staging/20260422_legal_governance_checks_phase1_seed.sql`
- status:
  - list route implemented
  - detail route implemented
  - acknowledge-warning route implemented
  - decision writes are ledger-only and do not mutate company policy
  - staging runtime may temporarily serve scoped fallback fixtures if the DB substrate is not yet readable

#### Reserved adoption family

- intended source path:
  - `app/api/legal/governance-checks/[id]/adopt-suggestion/route.ts`
  - `app/api/legal/governance-checks/[id]/keep-current/route.ts`
  - `app/api/legal/governance-checks/[id]/acknowledge-warning/route.ts`
- current status:
  - reserved
  - adopt-suggestion deferred
  - keep-current deferred

#### Reserved analysis family

- intended source path:
  - `app/api/legal/analyze/document/route.ts`
  - `app/api/legal/analyze/policy/route.ts`
- current status:
  - reserved
  - governance shape defined
  - implementation deferred

### Canonical Knowledge / Comparison Inputs

| Input | Phase 1 status | Notes |
| --- | --- | --- |
| official law / statute source refs | `planned` | should be curated and source-linked |
| administrative guidance refs | `planned` | includes ministry guidance and similar materials |
| customer current policy objects | `partial` | depends on target domain such as leave, payroll, attendance |
| AI-suggested comparison output | `planned` | advisory only |
| adoption / acknowledgement actions | `partial` | `acknowledge-warning` implemented; other action routes remain deferred |

### Ownership Notes

- system settings are platform-owned, not customer-owned
- customers may view governance results and perform adoption actions
- customers may not choose the base legal model or provider keys
- AI outputs are advisory until a human adoption record exists

### Governance Notes

- legal update events are distinct from governance checks
- governance checks compare statutory minimum, company current value, and AI suggested value
- governance checks formalize `rule_strength`, `company_decision_status`, and `impact_domain` in the canonical response
- adoption actions record human decision, not autonomous policy mutation
- analysis routes are customer-facing in outcome but system-governed in model control

### Non-goals Recorded In Source Governance

- direct automatic policy overwrite
- customer-controlled model switching
- insurer integration
- full autonomous legal execution
- uncontrolled real-time crawling
