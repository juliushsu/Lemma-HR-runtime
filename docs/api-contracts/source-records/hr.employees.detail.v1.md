# Employee API Source Record v1

## API Name

- name: `GET /api/hr/employees/:id`
- schema_version: `hr.employee.detail.v1`

## Canonical Source

- canonical source repo: `Lemma-HR-runtime`
- canonical source path: [app/api/hr/employees/[id]/route.ts](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/[id]/route.ts)
- canonical contract doc path: [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)

## Canonical Runtime Shape

Current canonical route behavior in this repo:

- path param supports:
  - UUID -> `employees.id`
  - non-UUID -> `employees.employee_code`
- success response is nested:
  - `data.employee`
  - `data.department`
  - `data.position`
  - `data.manager`
  - `data.current_assignment`

## Deploy Trace

- deploy target: `Railway staging`
- public base URL: `https://lemma-backend-staging-staging.up.railway.app`
- deploy method: `CLI upload`
- latest known deployment id: `unknown from current repo/workspace`

## Deployed Source Confirmation

- deployed source confirmed: `no`
- current status:
  - the current repo contains a canonical employee detail route
  - the current repo does **not** contain a separately identifiable `api-hr-employees` edge source file
  - staging runtime docs indicate Railway staging is deployed by CLI upload rather than git-linked source tracking

## Current Unresolved Risk

- frontend may be calling a runtime implementation that is not directly traceable to the canonical source path above
- local source and contract are aligned, but deployed source trace is incomplete
- this creates risk of runtime drift such as:
  - local source supports `employee_code`
  - contract documents nested response
  - deployed runtime may behave differently

## Next Action

1. identify the exact frontend-called employee detail URL in runtime
2. identify the deployed implementation source that serves that URL
3. record repo/path/commit/deployment id for the deployed source
4. compare deployed runtime with [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)
5. if runtime differs, either:
   - hotfix deployed implementation to match canonical contract
   - or explicitly re-designate canonical source and update contract + source record together

## Case Summary

This record exists because employee detail became the first concrete example of source drift risk:

- canonical local route is known
- canonical contract is known
- deployed source trace is not yet fully known

This file is the reference format for future API source records under:

- `docs/api-contracts/source-records/`
