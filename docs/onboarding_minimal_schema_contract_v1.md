# Onboarding Minimal Schema Contract v1 (Staging)

## A. Migration
- `supabase/migrations/20260404173000_employee_onboarding_minimal_schema.sql`

## B. Tables
1. `employee_onboarding_invitations`
2. `employee_onboarding_intake`
3. `employee_onboarding_documents`
4. `employee_onboarding_consents`
5. `employee_onboarding_signatures`
6. `employee_contract_deliveries`
7. `employee_data_access_logs`

## C. Table Fields

### 1) employee_onboarding_invitations
- `id`
- `org_id`
- `company_id`
- `employee_id`
- `environment_type`
- `is_demo`
- `invitee_name`
- `invitee_phone`
- `invitee_email`
- `preferred_language`
- `expected_start_date`
- `channel`
- `token_hash`
- `token_last4`
- `expires_at`
- `accepted_at`
- `status`
- `invited_by`
- `reviewed_by`
- `reviewed_at`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 2) employee_onboarding_intake
- `id`
- `org_id`
- `company_id`
- `employee_id`
- `invitation_id`
- `environment_type`
- `is_demo`
- `onboarding_status`
- `family_name_local`
- `given_name_local`
- `full_name_local`
- `family_name_latin`
- `given_name_latin`
- `full_name_latin`
- `birth_date`
- `phone`
- `email`
- `address`
- `emergency_contact_name`
- `emergency_contact_phone`
- `nationality_code`
- `identity_document_type`
- `is_foreign_worker`
- `notes`
- `submitted_at`
- `approved_at`
- `approved_by`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 3) employee_onboarding_documents
- `id`
- `org_id`
- `company_id`
- `employee_id`
- `invitation_id`
- `intake_id`
- `environment_type`
- `is_demo`
- `doc_type`
- `storage_bucket`
- `storage_path`
- `file_name`
- `mime_type`
- `file_size_bytes`
- `sensitivity_level`
- `is_required`
- `verification_status`
- `verified_by`
- `verified_at`
- `rejection_reason`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 4) employee_onboarding_consents
- `id`
- `org_id`
- `company_id`
- `invitation_id`
- `intake_id`
- `environment_type`
- `is_demo`
- `consent_type`
- `consent_version`
- `consent_text_snapshot`
- `is_checked`
- `checked_at`
- `ip_address`
- `user_agent`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 5) employee_onboarding_signatures
- `id`
- `org_id`
- `company_id`
- `employee_id`
- `invitation_id`
- `intake_id`
- `environment_type`
- `is_demo`
- `signature_type`
- `signature_storage_bucket`
- `signature_storage_path`
- `signed_at`
- `signer_name`
- `signer_locale`
- `ip_address`
- `user_agent`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 6) employee_contract_deliveries
- `id`
- `org_id`
- `company_id`
- `employee_id`
- `invitation_id`
- `legal_document_id`
- `environment_type`
- `is_demo`
- `delivery_channel`
- `delivered_at`
- `opened_at`
- `signed_at`
- `status`
- `delivery_ref`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

### 7) employee_data_access_logs
- `id`
- `org_id`
- `company_id`
- `environment_type`
- `is_demo`
- `viewer_user_id`
- `viewer_role`
- `resource_type`
- `resource_id`
- `action`
- `reason`
- `granted_basis`
- `viewed_at`
- `request_id`
- `created_at`
- `updated_at`
- `created_by`
- `updated_by`

## D. doc_type Enum (v1)
- `profile_photo`
- `national_id_front`
- `national_id_back`
- `education_certificate`
- `passport_page`
- `work_visa`
- `employment_contract`

## E. consent_type Enum (v1)
- `data_accuracy_declaration`
- `privacy_consent`
- `employment_terms_acknowledgement`

## F. signature_type Enum (v1)
- `intake_confirmation`
- `employment_contract`

## G. Bucket Proposal (Staging)
- `onboarding-documents`
- `onboarding-signatures`
- `employment-contracts`

Policy recommendation:
- all buckets `public = false`
- always read via signed URL (short TTL)
- write path via backend/service role only
- `restricted` docs (ID/passport/visa/signature) must never be public

## H. RLS Summary
- HR read/write baseline: `owner/admin/manager` with org/company scope.
- Sensitive protections:
  - `employee_onboarding_documents`: `restricted` requires `owner/admin`.
  - `employee_onboarding_signatures`: HR read limited to `owner/admin`.
  - `super_admin` not explicitly included in onboarding helper roles.
- Invitee self-access:
  - by invitation ownership (JWT email == invitation email), scope-checked by `(invitation_id, org_id, company_id, environment_type)`.
- Access logs:
  - append-only for non-service roles (`SELECT` + `INSERT`, no `UPDATE/DELETE` policy).

## I. Frontend Canonical Naming (Readdy-ready)
- Invitation:
  - `invitation_id`
  - `invitee_name`
  - `invitee_phone`
  - `invitee_email`
  - `preferred_language`
  - `expected_start_date`
  - `invitation_status`
- Intake:
  - `onboarding_status`
  - `profile_local_name` (map from `full_name_local`)
  - `profile_latin_name` (map from `full_name_latin`)
  - `emergency_contact_name`
  - `emergency_contact_phone`
  - `is_foreign_worker`
- Documents:
  - `doc_type`
  - `verification_status`
  - `sensitivity_level`
  - `file_name`
  - `file_size_bytes`
- Consent:
  - `consent_type`
  - `consent_version`
  - `is_checked`
  - `checked_at`
- Signature:
  - `signature_type`
  - `signed_at`
  - `signer_name`
  - `signer_locale`
- Contract delivery:
  - `delivery_channel`
  - `delivery_status` (map from `status`)
  - `delivered_at`
  - `opened_at`
  - `signed_at`
