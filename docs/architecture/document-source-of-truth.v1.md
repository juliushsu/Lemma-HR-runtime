# Document Source Of Truth v1

Status: formal documentation governance rule

Purpose:

- define which document surfaces are authoritative and which are draft-only
- stop Readdy, Codex, and frontend integration from relying on sandbox-only or unpublished docs as if they were final
- make document promotion and governance explicit

## 1. Official Document Source Priority

The official source-of-truth order is:

1. `GitHub docs/`
2. `Readdy sandbox docs`
3. `runtime hidden docs page`
4. `Supabase`

### 1.1 GitHub `docs/` = source of truth

GitHub-hosted repository docs under `docs/` are the only formal document truth-source.

This includes:

- architecture rules
- API contracts
- source records
- UI specs
- runbooks
- governance docs

If a rule or spec is not pushed to GitHub, it is not yet formal.

### 1.2 Readdy sandbox docs = draft only

Readdy sandbox docs are working drafts only.

They may be useful for:

- brainstorming
- early UI planning
- provisional mock alignment
- temporary drafting

They are not final authority.

A Readdy sandbox document must not be treated as final if it has not been promoted into GitHub docs.

### 1.3 Runtime hidden docs page = viewer only

A runtime hidden docs page may be used as a viewer or convenience surface.

It is not the canonical authoring location.

It may help:

- internal viewing
- QA verification
- quick reference

But it must not replace GitHub docs as the official truth-source.

### 1.4 Supabase = document registry / index only

Supabase should not be treated as the primary content truth-source for documentation.

If documentation metadata needs to be indexed in Supabase, its role should be:

- registry
- index
- lookup
- publication status tracking

Supabase must not become the canonical authoring layer for specs or governance docs.

## 2. Document Promotion Flow

The formal promotion flow is:

1. `Readdy draft`
2. `Codex correction / normalization`
3. `push to GitHub`
4. `adopt into contract / source governance`

### Step 1: Readdy draft

Readdy may create:

- exploratory notes
- UI-first drafting
- early mapping drafts
- provisional product or integration writeups

At this stage the document is still draft-only.

### Step 2: Codex correction / normalization

Codex should then:

- align naming
- align runtime truth
- align contract wording
- remove ambiguous or conflicting statements
- convert draft language into governance-safe wording

### Step 3: Push to GitHub

The document becomes formal only after:

- it exists under repo `docs/`
- it is committed
- it is pushed to GitHub

Until then, the document is not complete as a formal spec.

### Step 4: Adopt into contract / source governance

Once the document is on GitHub, it may be referenced by:

- API contract docs
- source records
- runtime governance docs
- UI specs
- implementation and integration decisions

## 3. AI Collaboration Rules

### Rule 1

Readdy must not treat sandbox-only documents as final authority.

Sandbox-only docs may guide exploration, but they cannot be used as final spec for:

- frontend integration
- canonical adapter behavior
- runtime ownership decisions
- source governance decisions

### Rule 2

Codex must not claim a specification is complete if it has not been pushed to GitHub.

A local-only or unpublished draft may be useful in progress, but it is not complete formal documentation.

### Rule 3

Before frontend integration starts, the integration owner must read the GitHub-hosted formal doc set.

Minimum expectation:

- read the relevant contract doc
- read the relevant source record
- read the relevant runtime governance or UI spec if applicable

### Rule 4

If GitHub doc and sandbox draft conflict, GitHub doc wins.

### Rule 5

If no GitHub doc exists yet, the correct status is:

- draft
- unresolved
- not governance-complete

It must not be described as final.

## 4. Operational Interpretation

When a collaborator asks “which document should we trust?”, use this answer:

- trust GitHub `docs/` first
- use Readdy sandbox docs only as draft context
- use hidden docs pages only as viewer surfaces
- use Supabase only as registry/index metadata, not as canonical doc body

## 5. Should We Create `doc_registry`?

Recommendation:

- `yes`, but only as a minimal registry/index layer
- `no` as a canonical content store

Reason:

- GitHub should continue owning document content truth
- Supabase can still help track publication metadata and lookup

## 6. Minimal `doc_registry` Schema Proposal

Suggested purpose:

- registry only
- publication index only
- not full document authoring

Suggested minimal table:

```sql
create table public.doc_registry (
  id uuid primary key default gen_random_uuid(),
  doc_key text not null unique,
  title text not null,
  repo_path text not null,
  github_url text not null,
  doc_type text not null,
  status text not null check (status in ('draft','published','deprecated')),
  source_surface text not null check (source_surface in ('github_docs','readdy_sandbox','runtime_viewer')),
  schema_version text null,
  last_published_commit text null,
  last_verified_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Suggested semantics:

- `doc_key`: stable logical identifier such as `hr.employees.get.v1`
- `repo_path`: canonical path under repository docs
- `github_url`: formal public/internal GitHub URL
- `doc_type`: `contract`, `source_record`, `architecture`, `ui_spec`, `runbook`
- `status`: draft vs published vs deprecated
- `source_surface`: where the current published document truth came from

### Constraints

If `doc_registry` is created:

- it must not store canonical document body as the authoritative source
- it must point to GitHub docs rather than replace them
- it should track publish status, not become a second documentation truth-source

## 7. Summary

Formal document truth must follow this order:

- GitHub `docs/`
- Readdy sandbox docs
- runtime hidden docs page
- Supabase registry/index

And formal promotion must follow this order:

- Readdy draft
- Codex correction
- push to GitHub
- governance adoption

The main rule is simple:

- if it is not on GitHub, it is not yet final
