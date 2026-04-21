## Source Record

### Family Owner

- owner: `payroll calculation / preview-first Phase 1`
- source_repo: `Lemma-HR-runtime`
- deploy_target: `Railway staging`
- deploy_method: `git-linked or CLI upload`
- deployment_id: `unknown`
- last_verified_at: `not yet implemented`

### Canonical Runtime Families

#### Settings family

- intended source path:
  - `app/api/payroll/settings/route.ts`
- contract doc:
  - `docs/api-contracts/payroll.settings.v1.md`
- schema versions:
  - read: `payroll.settings.v1`
  - write: `payroll.settings.update.v1`

#### Preview family

- intended source path:
  - `app/api/payroll/preview/route.ts`
  - `app/api/payroll/preview/[employee_id]/route.ts`
  - `app/api/payroll/preview/[employee_id]/breakdown/route.ts`
- contract doc:
  - `docs/api-contracts/payroll.preview.v1.md`
- schema versions:
  - list: `payroll.preview.list.v1`
  - detail: `payroll.preview.detail.v1`
  - breakdown: `payroll.preview.breakdown.v1`

#### Reserved but deferred family

- intended source path:
  - `app/api/payroll/components/route.ts`
- current status:
  - reserved only
  - deferred until preview detail and breakdown are stable

### Canonical Input Sources

| Input | Canonical source family | Phase 1 status | Notes |
| --- | --- | --- | --- |
| payroll settings | `/api/payroll/settings` | `planned` | company-level policy source of truth |
| approved leave data | leave family | `available` | approved leave only |
| attendance events | attendance domain substrate | `partial` | append-only source exists; preview read model still needs convergence |
| approved attendance corrections | attendance correction family | `available` | approved only |
| employee compensation settings | missing | `missing` | required for fully accurate preview |
| manual payroll adjustments | deferred | `deferred` | not part of Phase 1 |

### Governance Notes

- Phase 1 is preview-first and must not silently evolve into payroll run execution
- `/api/payroll/settings` is the company-scoped policy anchor
- `/api/payroll/preview*` is read-only
- future payroll run / closing must live under a separate route family
- employee compensation settings are not yet a canonical source and must be surfaced as missing when preview depends on them

### Non-goals Recorded In Source Governance

- payroll closing
- payslip issuance
- tax withholding output
- bank transfer export
- accounting integration
- multi-country payroll execution
