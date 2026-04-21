## Source Record

### Family Owner

- owner: `AI-assisted legal governance layer`
- source_repo: `Lemma-HR-runtime`
- deploy_target: `Railway staging`
- deploy_method: `git-linked or CLI upload`
- deployment_id: `unknown`
- last_verified_at: `not yet implemented`

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

- intended source path:
  - `app/api/legal/governance-checks/route.ts`
  - `app/api/legal/governance-checks/[id]/route.ts`
- contract doc:
  - `docs/api-contracts/legal.governance.v1.md`
- schema versions:
  - list: `legal.governance_check.list.v1`
  - detail: `legal.governance_check.detail.v1`

#### Reserved adoption family

- intended source path:
  - `app/api/legal/governance-checks/[id]/adopt-suggestion/route.ts`
  - `app/api/legal/governance-checks/[id]/keep-current/route.ts`
  - `app/api/legal/governance-checks/[id]/acknowledge-warning/route.ts`
- current status:
  - reserved
  - action semantics defined
  - implementation deferred

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
| adoption / acknowledgement actions | `reserved` | model defined, route may be deferred |

### Ownership Notes

- system settings are platform-owned, not customer-owned
- customers may view governance results and perform adoption actions
- customers may not choose the base legal model or provider keys
- AI outputs are advisory until a human adoption record exists

### Governance Notes

- legal update events are distinct from governance checks
- governance checks compare law, company policy, and suggested values
- adoption actions record human decision, not autonomous policy mutation
- analysis routes are customer-facing in outcome but system-governed in model control

### Non-goals Recorded In Source Governance

- direct automatic policy overwrite
- customer-controlled model switching
- insurer integration
- full autonomous legal execution
- uncontrolled real-time crawling
