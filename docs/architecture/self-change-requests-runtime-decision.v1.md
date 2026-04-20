# Self Change Requests Runtime Decision v1

## Runtime Decision Record

- API family name: `self change requests`
- intended consumers: self-service HR profile UI
- current runtime: `not yet deployed from this repo`
- canonical runtime: `Railway`
- source repo: `Lemma-HR-runtime`
- source path: [app/api/hr/self/change-requests/route.ts](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/self/change-requests/route.ts)
- deploy target: `Railway staging`
- deploy method: `CLI upload`
- contract doc path: [hr.self.change-requests.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.self.change-requests.v1.md)

## Why This Runtime

- why Railway / Edge / DB-RPC:
  - Railway is the canonical owner because this family depends on authenticated user resolution, selected context, server-side employee binding, and canonical HTTP contract shaping
- auth/session/context considerations:
  - frontend must not send `employee_id` as truth
  - route must resolve self employee from JWT + selected context + scoped employee binding
  - this is app-layer auth and scope orchestration, so it must stay in Railway
- workflow/business rule considerations:
  - request creation must force `pending`
  - request creation must not update employee master directly
  - future approve/apply flow will need explicit governance around request-vs-log separation
- read-model shaping considerations:
  - DB tables remain the data substrate
  - frontend-facing response shape still belongs in Railway

## Temporary Override

- temporary override: `no`
- temporary runtime source: `none`
- canonical design source: `Railway app route`
- source record path: [source-records/hr.self.change-requests.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/source-records/hr.self.change-requests.v1.md)
- exit criteria:
  - none required for Edge retirement because no temporary Edge runtime is designated

## Risks

- current risks:
  - target DB may not yet have the Phase 1 governance tables migrated
  - deployment trace is not yet recorded as fully verified
  - self employee binding currently depends on scoped email matching
- expected drift risks:
  - frontend bypassing Railway and treating DB tables as direct API substrate
  - later approval flow writing employee master directly without preserving request-vs-log separation
  - future alternate runtime appearing without a source record
- mitigations:
  - keep canonical runtime as Railway
  - require source record + contract doc before frontend integration
  - keep `employee_change_logs` deferred until explicit approve/apply design is added

## Approval

- owner: `Codex / HR runtime governance`
- approver: `pending`
- decision date: `2026-04-20`
- last verified at: `2026-04-20`
