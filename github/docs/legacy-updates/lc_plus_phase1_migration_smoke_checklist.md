# LC+ Phase 1 + Phase 1.1 Migration Smoke Checklist

Scope:
- Existing LC+ routes (no contract change):
  - `GET/POST /api/legal/documents`
  - `GET /api/legal/documents/:id`
  - `POST /api/legal/documents/:id/versions`
  - `GET/POST /api/legal/cases`
  - `GET/POST /api/legal/cases/:id/documents`
  - `POST /api/legal/storage/upload-url`
- New DB object:
  - `legal_case_events` (from incremental migration)

## 1) Apply Order

1. Foundation migration:
   - `supabase/migrations/20260401144000_core_schema_rbac_auth_locale_rls.sql`
2. LC+ Phase 1 migration:
   - `supabase/migrations/20260401162000_lc_plus_phase1_core.sql`
3. LC+ Phase 1.1 incremental migration:
   - `supabase/migrations/20260401173000_lc_plus_phase1_1_legal_case_events.sql`
4. Demo seed:
   - `supabase/seeds/demo/lc_plus_phase1_demo_seed.sql`

## 2) Schema Verification SQL (Read-only)

```sql
-- table exists
select table_name
from information_schema.tables
where table_schema='public'
  and table_name in (
    'legal_documents','legal_document_versions','legal_document_tags',
    'legal_cases','legal_case_documents','legal_case_events'
  )
order by table_name;

-- RLS enabled
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname='public'
  and c.relname in (
    'legal_documents','legal_document_versions','legal_document_tags',
    'legal_cases','legal_case_documents','legal_case_events'
  )
order by c.relname;

-- policy exists
select tablename, policyname
from pg_policies
where schemaname='public'
  and tablename in (
    'legal_documents','legal_document_versions','legal_document_tags',
    'legal_cases','legal_case_documents','legal_case_events'
  )
order by tablename, policyname;
```

## 3) Seed Verification SQL

```sql
select count(*) as document_count from public.legal_documents;
select count(*) as version_count from public.legal_document_versions;
select count(*) as tag_count from public.legal_document_tags;
select count(*) as case_count from public.legal_cases;
select count(*) as case_document_count from public.legal_case_documents;
select count(*) as case_event_count from public.legal_case_events;

select id, document_code, title, current_version_id
from public.legal_documents
order by created_at desc
limit 5;

select id, case_code, title, status
from public.legal_cases
order by created_at desc
limit 5;
```

## 4) API Smoke (Existing Contract Only)

Use any valid bearer token with membership scope.

### A. List documents

```bash
curl -sS -H "Authorization: Bearer <TOKEN>" \
  "http://localhost:3000/api/legal/documents"
```

Expected:
- HTTP 200
- `schema_version = legal.document.list.v1`
- `data.items` length >= 1

### B. Document detail

```bash
curl -sS -H "Authorization: Bearer <TOKEN>" \
  "http://localhost:3000/api/legal/documents/<LEGAL_DOCUMENT_ID>"
```

Expected:
- HTTP 200
- `schema_version = legal.document.detail.v1`
- `data.legal_document` not null
- `data.versions` array
- `data.tags` array

### C. List cases

```bash
curl -sS -H "Authorization: Bearer <TOKEN>" \
  "http://localhost:3000/api/legal/cases"
```

Expected:
- HTTP 200
- `schema_version = legal.case.list.v1`
- `data.items` length >= 1

### D. Case documents

```bash
curl -sS -H "Authorization: Bearer <TOKEN>" \
  "http://localhost:3000/api/legal/cases/<LEGAL_CASE_ID>/documents"
```

Expected:
- HTTP 200
- `schema_version = legal.case.documents.list.v1`
- linked document rows present

### E. Upload URL handler

```bash
curl -sS -X POST -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
  -d '{"legal_document_id":"<LEGAL_DOCUMENT_ID>","file_name":"demo.pdf"}' \
  "http://localhost:3000/api/legal/storage/upload-url"
```

Expected:
- HTTP 200
- `schema_version = legal.storage.upload_url.create.v1`
- `data.path` and `data.token` present

## 5) New `legal_case_events` Validation

```sql
select legal_case_id, event_date, event_type, description
from public.legal_case_events
order by created_at desc
limit 20;
```

Expected:
- at least one event row from demo seed
- all rows carry valid org/company/environment scope values

## 6) Failure Cases

1. Missing auth token
- expected HTTP 401 on all `/api/legal/*` routes

2. Wrong org/company/environment scope
- expected HTTP 403 or empty list based on route behavior

3. Missing migration `20260401173000...`
- query against `legal_case_events` should fail (table missing), indicating migration not yet applied
