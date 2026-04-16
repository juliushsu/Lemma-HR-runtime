# LC+ Canonical Schema Proposal v1 (Draft, No Migration in This Round)

## 1. Scope and Non-Goal

This document defines schema proposal only.

This round does not:
- execute migration
- create LC+ API routes
- modify existing DB objects

## 2. Canonical Standards

Naming:
- DB: `snake_case`
- enum values: lower_snake_case

Mandatory columns for core tables:
- `id` (uuid)
- `org_id`
- `company_id`
- `branch_id` (nullable when not applicable)
- `environment_type` (`production|demo|sandbox|seed`)
- `is_demo` (boolean)
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

RLS target baseline (future implementation):
- same org visibility
- company/branch scope narrowing
- strict demo vs production separation

## 3. Proposed Core Tables

### 3.1 `legal_documents`

Purpose:
- legal document master (contract/policy/memo)

Key fields:
- `document_code`
- `title`
- `document_type` (`employment_contract|procurement_contract|sales_contract|nda|policy|memo|other`)
- `governing_law_code`
- `jurisdiction_note`
- `counterparty_name`
- `counterparty_type`
- `effective_date`
- `expiry_date`
- `auto_renewal_date`
- `signing_status`
- `current_version_id`
- `source_module`
- `source_record_id`

Suggested constraints:
- unique: `(org_id, company_id, document_code, environment_type)`

### 3.2 `legal_document_versions`

Purpose:
- immutable-ish version chain for each legal document

Key fields:
- `legal_document_id`
- `version_no`
- `storage_path`
- `file_name`
- `file_ext`
- `mime_type`
- `file_size_bytes`
- `checksum`
- `uploaded_by`
- `uploaded_at`
- `is_current`
- `parsed_status`
- `parsing_error`

Suggested constraints:
- unique: `(legal_document_id, version_no)`
- partial unique: one current version per document (`is_current=true`)

### 3.3 `legal_document_tags`

Purpose:
- normalized tag mapping

Key fields:
- `legal_document_id`
- `tag`

Suggested constraints:
- unique: `(legal_document_id, tag)`

### 3.4 `legal_cases`

Purpose:
- dispute/case workspace root entity

Key fields:
- `case_code`
- `case_type` (`labor_dispute|contract_breach|payment_dispute|procurement_dispute|ip_dispute|other`)
- `title`
- `status` (`open|under_review|strategy_prepared|external_counsel|closed`)
- `governing_law_code`
- `forum_note`
- `risk_level`
- `summary`
- `owner_user_id`

Suggested constraints:
- unique: `(org_id, company_id, case_code, environment_type)`

### 3.5 `legal_case_documents`

Purpose:
- mapping between cases and legal documents

Key fields:
- `legal_case_id`
- `legal_document_id`
- `relationship_type` (optional, proposed)

Suggested constraints:
- unique: `(legal_case_id, legal_document_id)`

### 3.6 `legal_case_events`

Purpose:
- timeline records for case evolution

Key fields:
- `legal_case_id`
- `event_date`
- `event_type`
- `description`
- `source_document_id`

Suggested indexes:
- `(legal_case_id, event_date)`

### 3.7 `legal_ai_analyses`

Purpose:
- AI analysis trace and output storage

Key fields:
- `legal_case_id` (nullable)
- `legal_document_id` (nullable)
- `analysis_type` (`summary|clause_extraction|risk_review|first_pass_liability|attack_strategy|defense_strategy|question_list`)
- `governing_law_code`
- `input_page_count`
- `input_token_estimate`
- `output_token_count`
- `points_consumed`
- `model_name`
- `analysis_status`
- `result_json`
- `result_markdown`
- `disclaimer_text`

Suggested constraints:
- check: at least one target exists (`legal_case_id` or `legal_document_id`)

### 3.8 `legal_credit_ledgers`

Purpose:
- credit accounting and auditable point balances

Key fields:
- `transaction_type` (`monthly_grant|top_up|usage|refund|manual_adjustment`)
- `points_delta`
- `balance_after`
- `reference_type`
- `reference_id`
- `note`

Suggested indexes:
- `(org_id, created_at)`
- `(org_id, reference_type, reference_id)`

## 4. Proposed Enum Strategy

For MVP:
- use text + check constraints for faster change management.

For later hardening:
- promote stable sets to enum types if churn is low.

## 5. Cross-Module Link Strategy

For `legal_documents.source_module`:
- suggested values: `hr_plus|po_plus|so_plus|acc_plus|lc_plus`

`source_record_id`:
- stores linked record ID from source module.

## 6. AI Output Canonical Contract (Fixed)

Store and serve by:
- `schema_version = legal.first_pass.v1`
- output JSON shape fixed as defined in product spec

Reference:
- `/docs/lc_plus/lc_plus_product_spec_v1.md`

## 7. Minimal API Surface (Future, Not This Round)

Draft-only, no implementation now:
- `GET/POST /api/legal/documents`
- `GET/POST /api/legal/cases`
- `POST /api/legal/analyses/first-pass`
- `GET /api/legal/credits/ledger`

All responses should follow envelope:

```json
{
  "schema_version": "xxx.v1",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "ISO-8601"
  },
  "error": null
}
```

## 8. Implementation Gate

Before any migration is written, all of the following must be confirmed:
1. product spec freeze approved
2. schema proposal freeze approved
3. role matrix approved (`legal_admin/legal_editor/legal_reviewer/legal_viewer`)
4. legal disclaimer and refusal policy approved
5. demo data policy approved

