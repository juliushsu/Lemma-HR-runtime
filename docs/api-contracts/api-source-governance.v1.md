# API Source Governance Rule v1

## Purpose

Prevent API ownership drift where:

- local source is A
- contract doc is B
- deployed runtime is C

This rule defines the minimum traceability required for every API in Lemma HR+.

## Scope

Applies to:

- app routes under `app/api/**`
- external API adapters used by frontend
- Supabase edge functions if used as frontend-facing APIs
- any staging or sandbox deployment that serves canonical product traffic

## 1. Required Fields Per API

Every API must have one current truth record that includes all of the following:

| Field | Meaning |
| --- | --- |
| `source_repo` | the git repository that owns the implementation currently intended to be canonical |
| `source_path` | the exact file path of the implementation source |
| `deploy_target` | where the API is currently deployed, such as Railway staging or Supabase edge |
| `deploy_method` | how the runtime was deployed, such as git-linked deploy, CLI upload, or manual edge deploy |
| `contract_doc_path` | the single authoritative contract document path under `docs/api-contracts/` |
| `deployment_id` | the current deployment identifier if the platform exposes one; if unknown, it must be recorded as unknown, not omitted |

Recommended additional fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | current runtime schema version |
| `owner` | responsible team or engineer |
| `last_verified_at` | last time source/contract/deploy alignment was checked |
| `notes` | temporary known gaps, for example deployed source not yet traced |

## 2. Definition Of Done

An API change is not complete unless all of the following are true:

1. current runtime contract doc exists under `docs/api-contracts/`
2. source repo and source path are explicitly identified
3. deploy target and deploy method are explicitly identified
4. deployed source is traceable to a branch and commit, or the gap is explicitly recorded and treated as unresolved
5. response shape and contract doc agree

An API is **not done** if any of the following is true:

- no contract doc
- source path unknown
- deploy source not traceable
- current deployment target unknown
- frontend is consuming a runtime that is not tied to the documented canonical source

## 3. CLI Deploy Rule

If staging or sandbox still permits CLI upload deployment, each deploy must record at minimum:

| Field | Required value |
| --- | --- |
| local folder | absolute or repo-root-relative path used for deploy |
| repo | source repository name or remote URL |
| branch | git branch used at deploy time |
| commit | git commit SHA used at deploy time |
| deploy target | exact target service/environment |
| deploy method | `cli_upload` |
| deployment id | platform deployment id if available |
| contract doc | the matching contract doc path |

### Required recording rule

The deploy operator must record the above fields in one of these places:

- deployment runbook
- release note
- API source registry document

If no deployment id is available, record:

- `deployment_id: unknown`

This must be treated as a traceability gap, not as acceptable silence.

## 4. Canonical Source Rule

For each frontend-facing API, there must be exactly one canonical implementation source.

Allowed:

- one app route plus one contract doc
- one edge function plus one contract doc

Not allowed:

- app route documented as canonical while frontend actually calls a different edge implementation
- contract doc describing one shape while deployed runtime serves another
- undocumented fallback switching between multiple API sources

## 5. Source Tracing Workflow

When an API bug is reported, follow this order:

1. identify the frontend-called URL
2. identify the deploy target serving that URL
3. identify the exact source repo and path for that deployed implementation
4. compare runtime response with `docs/api-contracts/*`
5. only after source and contract are aligned, debug adapter/UI behavior

## 6. Employee API Case Study

### Canonical source

For employee detail in this repo, the documented canonical source is:

- source repo: `Lemma-HR-runtime`
- source path: [`app/api/hr/employees/[id]/route.ts`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/app/api/hr/employees/[id]/route.ts)
- contract doc: [hr.employees.get.v1.md](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/hr.employees.get.v1.md)

Current runtime contract in this repo:

- `GET /api/hr/employees/:id`
- UUID lookup by `employees.id`
- non-UUID lookup by `employees.employee_code`
- nested response:
  - `data.employee`
  - `data.department`
  - `data.position`
  - `data.manager`
  - `data.current_assignment`

### Known risk

The current staging deployment trail is incomplete:

- Railway staging is documented as CLI-uploaded
- deployed source for the suspected `api-hr-employees` implementation is not fully traceable from this repo alone
- this creates a live risk where frontend may hit a runtime different from the documented canonical source

### Why this is dangerous

It allows the exact failure mode we are trying to prevent:

- local route says nested
- contract doc says nested
- deployed runtime may be flat or may not support `employee_code`
- frontend then debugs the wrong layer

### Required follow-up for employee API

To close the governance gap, employee detail must gain a source trace record containing:

| Field | Current status |
| --- | --- |
| `source_repo` | known for local canonical source |
| `source_path` | known for local canonical source |
| `deploy_target` | known: Railway staging |
| `deploy_method` | known: CLI upload |
| `contract_doc_path` | known |
| `deployment_id` | currently unknown from this repo |
| `deployed_source_repo` | unresolved if deployed runtime is not this repo build |
| `deployed_source_path` | unresolved if deployed runtime is not this repo build |

### Prevention rule

Before future employee detail changes ship:

1. verify frontend-called source path
2. verify deployed implementation matches the canonical route or update the canonical record
3. verify contract doc matches deployed runtime
4. reject deploy if deployed source cannot be traced to repo + path + commit

## 7. Minimum Template

Use this template for future API source records:

```md
## Source Record

- source_repo:
- source_path:
- deploy_target:
- deploy_method:
- contract_doc_path:
- deployment_id:
- schema_version:
- last_verified_at:
- notes:
```

## 8. Practical Rule Summary

- one API, one canonical source
- one API, one contract doc
- every deploy must be traceable to repo/path/commit
- unknown deployed source is a release blocker, not a documentation footnote
