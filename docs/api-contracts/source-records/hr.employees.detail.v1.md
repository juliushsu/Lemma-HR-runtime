# Employee API Source Record v1

## API Name

- name: `GET /api/hr/employees/:id`
- schema_version: `hr.employee.detail.v1`

## Canonical Source

- canonical source repo: `Lemma-HR-runtime`
- canonical source path: [app/api/hr/employees/[id]/route.ts](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/[id]/route.ts)
- canonical contract doc path: [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)
- canonical design source type: `Railway app route`

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

## Temporary Runtime Override

- temporary runtime source: `Supabase edge function api-hr-employees`
- temporary runtime role: frontend-facing employee detail runtime currently used for integration validation
- current runtime shape status: aligned to the nested contract
  - `data.employee`
  - `data.department`
  - `data.position`
  - `data.manager`
  - `data.current_assignment`
- governance status: this is a temporary runtime override, not final source-governance closure

## Deployed Source Confirmation

- deployed source confirmed: `partially`
- current status:
  - the current repo contains a canonical employee detail route
  - current frontend runtime is treated as `api-hr-employees` on Supabase edge
  - the current repo does **not** contain a separately identifiable `api-hr-employees` edge source file
  - staging runtime docs indicate Railway staging is deployed by CLI upload rather than git-linked source tracking

## Current Unresolved Risk

- frontend runtime is temporarily served by a non-canonical runtime source
- local canonical source and contract are aligned, but the temporary runtime override is not yet governed back to the canonical Railway source path
- this creates risk of runtime drift such as:
  - local source supports `employee_code`
  - contract documents nested response
  - temporary runtime override may later diverge again unless exit criteria are enforced

## Exit Criteria For Returning To Canonical Railway Runtime

The temporary runtime override may be removed only when all of the following are true:

1. Railway runtime for `GET /api/hr/employees/:id` matches [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)
2. Railway runtime supports the canonical lookup rule:
   - UUID -> `employees.id`
   - non-UUID -> `employees.employee_code`
3. Railway runtime returns the nested contract shape:
   - `data.employee`
   - `data.department`
   - `data.position`
   - `data.manager`
   - `data.current_assignment`
4. frontend employee detail adapter request target is explicitly switched back to Railway canonical runtime
5. the source record is updated so temporary runtime override is removed and deployed source trace is fully resolved

## Next Action

1. keep the temporary runtime override explicitly documented as `api-hr-employees`
2. verify Railway runtime against [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)
3. once Railway runtime matches contract, switch frontend employee detail request target back to Railway canonical route
4. record repo/path/commit/deployment id for the canonical deployed source
5. remove the temporary runtime override note only after the exit criteria above are met

## Case Summary

This record exists because employee detail became the first concrete example of source drift risk:

- canonical local route is known
- canonical contract is known
- a temporary Supabase edge runtime override exists
- governance is not complete until runtime is switched back to the canonical Railway source or the canonical source is formally re-designated

This file is the reference format for future API source records under:

- `docs/api-contracts/source-records/`
