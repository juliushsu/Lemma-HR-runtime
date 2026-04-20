## Source Record

- source_repo: `Lemma-HR-runtime`
- source_path:
  - implementation target: `app/api/hr/change-requests/route.ts`
  - implementation target: `app/api/hr/change-requests/[id]/approve/route.ts`
  - implementation target: `app/api/hr/change-requests/[id]/reject/route.ts`
- deploy_target: `Railway staging`
- deploy_method: `git-linked or CLI upload`
- contract_doc_path: `docs/api-contracts/hr.change-requests.v1.md`
- deployment_id: `unknown`
- schema_version:
  - list: `hr.change_requests.list.v1`
  - action: `hr.change_requests.action.v1`
- owner: `HR runtime / change governance`
- last_verified_at: `2026-04-20`
- notes:
  - this record establishes the canonical family before deploy trace exists
  - implementation target is declared, but route deploy trace is not yet recorded
  - this family is the canonical HR review counterpart to `docs/api-contracts/source-records/hr.self.change-requests.v1.md`
