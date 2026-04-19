# Doc Registry Proposal v1

Status: proposal only

Purpose:

- define a concrete `doc_registry` concept before any schema or runtime work starts
- make document publication status queryable without turning Supabase into the document truth-source
- give Readdy, Codex, CTO, and future tooling one lightweight registry for document lookup and governance checks

Non-goals in this round:

- no migration
- no table creation
- no runtime route
- no sync worker
- no automatic GitHub integration

## 1. Purpose

`doc_registry` is proposed as a metadata index for formal documentation.

Its job is to answer questions like:

- does this document exist?
- is it draft or published?
- what GitHub path is the formal source?
- which contract / source record / architecture doc applies to this API family?
- when was this document last verified?

It is **not** intended to store canonical document body content.

## 2. Why Supabase Should Be Index Only, Not Source Of Truth

Supabase is a good fit for:

- indexing
- lookup
- status tracking
- cross-document references
- internal dashboards or admin tooling

Supabase is a bad fit for canonical documentation truth because:

- document content then becomes split across GitHub and database
- version history becomes harder to reason about than Git-based history
- review and approval become less visible than normal Git workflow
- frontend and AI collaborators may start reading DB rows instead of formal docs
- it creates a second content authoring surface

Therefore the correct model is:

- GitHub `docs/` owns canonical document content
- Supabase `doc_registry` only indexes published metadata

## 3. Minimal Schema

Suggested minimal table:

```sql
create table public.doc_registry (
  id uuid primary key default gen_random_uuid(),
  doc_key text not null unique,
  title text not null,
  doc_type text not null,
  repo_path text not null,
  github_url text not null,
  status text not null check (status in ('draft', 'published', 'deprecated')),
  source_surface text not null check (
    source_surface in ('github_docs', 'readdy_sandbox', 'runtime_viewer')
  ),
  schema_version text null,
  related_api_family text null,
  last_published_commit text null,
  last_verified_at timestamptz null,
  owner text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## 4. Field Semantics

| Field | Meaning |
| --- | --- |
| `doc_key` | stable logical identifier, for example `hr.employees.get.v1` |
| `title` | human-readable document title |
| `doc_type` | `contract`, `source_record`, `architecture`, `ui_spec`, `runbook` |
| `repo_path` | canonical path under repository docs |
| `github_url` | GitHub URL for the formal document |
| `status` | lifecycle state: `draft`, `published`, `deprecated` |
| `source_surface` | where the currently recognized doc came from |
| `schema_version` | optional version label when the document governs a versioned contract |
| `related_api_family` | optional API family grouping such as `hr.employees.detail` |
| `last_published_commit` | Git commit SHA that last published this doc |
| `last_verified_at` | last time a human or approved workflow confirmed it is still current |
| `owner` | responsible role, team, or engineer |
| `notes` | bounded free-text context |

## 5. Example Rows

Illustrative rows:

```json
[
  {
    "doc_key": "hr.employees.get.v1",
    "title": "GET /api/hr/employees/:id Contract",
    "doc_type": "contract",
    "repo_path": "docs/api-contracts/hr.employees.get.v1.md",
    "github_url": "https://github.com/juliushsu/Lemma-HR-runtime/blob/main/docs/api-contracts/hr.employees.get.v1.md",
    "status": "published",
    "source_surface": "github_docs",
    "schema_version": "hr.employee.detail.v1",
    "related_api_family": "hr.employees.detail",
    "last_published_commit": "abc1234",
    "last_verified_at": "2026-04-19T10:00:00Z",
    "owner": "Codex",
    "notes": "Canonical GET contract"
  },
  {
    "doc_key": "hr.employees.detail.source-record.v1",
    "title": "Employee Detail Source Record",
    "doc_type": "source_record",
    "repo_path": "docs/api-contracts/source-records/hr.employees.detail.v1.md",
    "github_url": "https://github.com/juliushsu/Lemma-HR-runtime/blob/main/docs/api-contracts/source-records/hr.employees.detail.v1.md",
    "status": "published",
    "source_surface": "github_docs",
    "schema_version": null,
    "related_api_family": "hr.employees.detail",
    "last_published_commit": "def5678",
    "last_verified_at": "2026-04-19T10:10:00Z",
    "owner": "Codex",
    "notes": "Documents temporary GET runtime override"
  },
  {
    "doc_key": "hr.employee.detail.null-policy.v1",
    "title": "HR Employee Detail Null Policy",
    "doc_type": "ui_spec",
    "repo_path": "docs/ui-specs/hr-employee-detail-null-policy.v1.md",
    "github_url": "https://github.com/juliushsu/Lemma-HR-runtime/blob/main/docs/ui-specs/hr-employee-detail-null-policy.v1.md",
    "status": "published",
    "source_surface": "github_docs",
    "schema_version": null,
    "related_api_family": "hr.employees.detail",
    "last_published_commit": "ghi9012",
    "last_verified_at": "2026-04-19T10:15:00Z",
    "owner": "Codex",
    "notes": "Render policy only"
  }
]
```

## 6. Sync / Update Workflow

Recommended workflow:

1. draft or update the document in the normal authoring surface
2. normalize and approve the document content
3. commit and push the document to GitHub
4. update `doc_registry` metadata
5. mark `status = published` only after GitHub publication exists

### Key rule

Registry update happens **after** GitHub publication, not before.

This avoids the bad state where the registry claims a doc is published while GitHub does not yet contain the final content.

## 7. Who Writes It

Recommended ownership:

- `Codex` or an approved backend/documentation maintainer updates the registry metadata
- `Readdy` may propose draft metadata, but should not be the final publisher of the formal registry entry unless the GitHub document is already published

Long-term options:

- manual update by Codex during documentation publish flow
- semi-automated update via future tooling after GitHub push

## 8. When It Should Be Updated

`doc_registry` should be updated when:

- a new formal document is published to GitHub
- a document path changes
- a document status changes:
  - `draft`
  - `published`
  - `deprecated`
- a contract version changes
- a source record changes enough to affect governance interpretation
- an API family gains a new required companion document

It should not need updates for:

- casual note edits that do not affect status, path, or governance meaning

## 9. Risks If Omitted

If `doc_registry` does not exist, the system can still function, but these risks remain:

- harder document discovery across contracts, source records, UI specs, and governance docs
- harder automation for documentation completeness checks
- harder internal dashboards for “which docs are published vs draft”
- higher chance that collaborators read outdated or wrong document surfaces
- more manual effort to answer “what is the current official doc for this API family?”

The biggest risk is not runtime failure.
The biggest risk is governance friction and slower debugging/alignment.

## 10. Recommended Adoption Rule

If `doc_registry` is implemented later, adopt these rules:

- registry is metadata-only
- GitHub remains canonical content source
- `status = published` must point to a valid GitHub document
- no unpublished local-only draft may be marked as formal

## 11. Summary

`doc_registry` is recommended as a minimal metadata index, not as a second documentation truth-source.

Correct model:

- GitHub owns document content
- Supabase tracks document metadata
- publication status is updated after GitHub push
- registry helps lookup and governance, but does not replace source-of-truth docs
