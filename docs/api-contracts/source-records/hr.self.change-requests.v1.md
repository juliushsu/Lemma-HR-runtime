# Self Change Requests API Source Record v1

## API Name

- name: `GET / POST /api/hr/self/change-requests`
- schema versions:
  - `hr.self.change_requests.list.v1`
  - `hr.self.change_requests.create.v1`

## Canonical Source

- canonical source repo: `Lemma-HR-runtime`
- canonical source path: [app/api/hr/self/change-requests/route.ts](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/self/change-requests/route.ts)
- canonical contract doc path: [hr.self.change-requests.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.self.change-requests.v1.md)
- canonical design source type: `Railway app route`

## Canonical Runtime Shape

Current canonical route behavior in this repo:

- `GET` lists only the server-resolved self employee's change requests
- `POST` creates one pending request for one supported field at a time
- runtime never writes employee master directly
- runtime never writes `employee_change_logs` during request creation

## Deploy Trace

- deploy target: `Railway staging`
- public base URL: `https://lemma-backend-staging-staging.up.railway.app`
- deploy method: `CLI upload`
- latest known deployment id: `unknown from current repo/workspace`

## Internal Data Substrate

- primary tables:
  - `public.employee_change_requests`
  - `public.employees`
- deferred audit table:
  - `public.employee_change_logs`
- write substrate type: `DB direct table writes behind Railway-owned contract`

## Temporary Runtime Override

- temporary runtime override: `no`
- temporary runtime source: `none`
- current status: canonical design and canonical runtime are both Railway-owned

## Deployed Source Confirmation

- deployed source confirmed: `not yet`
- current status:
  - canonical source path is defined in this repo
  - contract doc exists
  - source record exists
  - deploy target is known
  - deployment trace is not yet confirmed for a live deployed revision

## Current Risk

- deployment trace is still incomplete
- service-role-backed DB write path requires environment configuration at runtime
- `employee_change_requests` migration must be present in the target DB before the route can be considered runtime-ready

## Exit Criteria For Governance Closure

This source record is governance-complete only when all of the following are true:

1. Railway staging deploy includes [app/api/hr/self/change-requests/route.ts](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/self/change-requests/route.ts)
2. target DB contains `public.employee_change_requests`
3. runtime matches [hr.self.change-requests.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.self.change-requests.v1.md)
4. deployment trace is recorded with repo + branch + commit + deployment id
5. no alternate Edge or DB-direct frontend-facing runtime is serving this API family
