# Employee Lifecycle Schema Contract v1

## Purpose

Record the canonical Phase 1 database contract for employee lifecycle staging rollout.

## Tables

### `public.candidates`

Key columns:

- `id`
- `org_id`
- `company_id`
- `branch_id`
- `environment_type`
- `candidate_code`
- `full_name`
- `personal_email`
- `mobile_phone`
- `source`
- `candidate_status`
- `applied_position_id`

Indexes:

- `candidates_scope_status_idx`
- `candidates_email_idx`

### `public.onboarding_profiles`

Key columns:

- `id`
- `candidate_id`
- `onboarding_code`
- `onboarding_status`
- `legal_name`
- `preferred_name`
- `personal_email`
- `mobile_phone`
- `expected_start_date`
- `approved_by`
- `approved_at`
- `converted_at`

Indexes:

- `onboarding_profiles_scope_status_idx`
- `onboarding_profiles_candidate_idx`

### `public.onboarding_documents`

Key columns:

- `id`
- `onboarding_profile_id`
- `document_type`
- `storage_bucket`
- `storage_path`
- `file_name`
- `mime_type`
- `verification_status`
- `verified_by`
- `verified_at`

Indexes:

- `onboarding_documents_profile_idx`
- `onboarding_documents_scope_idx`

### `public.onboarding_signatures`

Key columns:

- `id`
- `onboarding_profile_id`
- `signature_type`
- `signature_status`
- `signer_name`
- `signer_email`
- `signature_artifact_url`
- `signed_at`

Indexes:

- `onboarding_signatures_profile_idx`
- `onboarding_signatures_scope_idx`

### `public.employees`

Phase 1 additive alignment:

- `source_onboarding_profile_id`

Constraint intent:

- employee rows are materially linked back to one onboarding profile
- onboarding source is immutable once set

## RLS Contract

- candidates:
  - read: `can_read_scope(...)`
  - write: `can_write_scope(...)`
- onboarding profiles/documents/signatures:
  - read: `can_read_scope(...)`
  - write: `can_write_scope(...)`

## Phase 1 Compatibility Notes

- Existing legacy `employee_onboarding_*` tables are not removed.
- This contract defines the canonical target schema, not a full runtime cutover.
