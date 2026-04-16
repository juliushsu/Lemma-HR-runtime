# LC+ Phase 1.5 Design (Spec Only, No Migration/Route in This Round)

Topic:
- LINE Access Request Flow
- Identity Mapping
- Audit Logging

Constraints:
- This is document/spec/proposal only.
- No migration execution.
- No `/api/legal/*` contract change.
- No LINE webhook route implementation in this round.

## 1) Objective

Add enterprise-safe legal document access control flow over LINE while preserving LC+ Phase 1 core.

Main outcomes:
1. requester cannot directly obtain protected legal file without approval when policy requires approval.
2. approvals are auditable and attributable.
3. LINE identities are mapped to internal users safely.

## 2) Proposed Tables (Schema Proposal Only)

### 2.1 `line_bindings`

Purpose:
- bind LINE identity to internal user.

Suggested fields:
- `id` uuid pk
- `org_id` uuid not null
- `company_id` uuid not null
- `branch_id` uuid null
- `environment_type` text not null
- `is_demo` boolean not null default false
- `line_user_id` text not null
- `line_channel_id` text not null
- `user_id` uuid not null
- `bind_status` text not null (`active|revoked|pending`)
- `bound_at` timestamptz not null
- `revoked_at` timestamptz null
- `created_at` / `updated_at` / `created_by` / `updated_by`

Constraints (suggested):
- unique (`line_channel_id`, `line_user_id`, `environment_type`)
- unique (`org_id`, `company_id`, `user_id`, `line_channel_id`, `environment_type`) where `bind_status='active'`

### 2.2 `line_event_logs`

Purpose:
- raw inbound/outbound event audit trail for LINE interactions.

Suggested fields:
- `id` uuid pk
- `org_id` uuid not null
- `company_id` uuid not null
- `branch_id` uuid null
- `environment_type` text not null
- `is_demo` boolean not null default false
- `line_channel_id` text not null
- `line_user_id` text null
- `event_type` text not null
- `event_id` text null
- `request_payload` jsonb null
- `response_payload` jsonb null
- `status_code` int null
- `error_code` text null
- `error_message` text null
- `created_at` timestamptz not null
- `created_by` uuid null

Indexes (suggested):
- (`line_channel_id`, `created_at`)
- (`event_id`)

### 2.3 `access_requests`

Purpose:
- legal document access approval workflow.

Suggested fields:
- `id` uuid pk
- `org_id` uuid not null
- `company_id` uuid not null
- `branch_id` uuid null
- `environment_type` text not null
- `is_demo` boolean not null default false
- `requester_user_id` uuid not null
- `approver_user_id` uuid not null
- `legal_document_id` uuid not null
- `request_reason` text not null
- `status` text not null (`pending|approved|rejected|expired|cancelled`)
- `approved_at` timestamptz null
- `rejected_at` timestamptz null
- `decision_note` text null
- `download_token_id` uuid null
- `token_expires_at` timestamptz null
- `created_at` / `updated_at` / `created_by` / `updated_by`

Constraints (suggested):
- only one open request per requester/document in pending state (partial unique)
- approver cannot equal requester (business rule check in service layer)

## 3) Canonical Flow (LINE Access Request)

1. User asks in LINE: "我要 Tanaka 的合約"
2. Backend resolves LINE identity:
   - `line_user_id` + `line_channel_id` -> `line_bindings.user_id`
3. Backend searches accessible metadata only:
   - return title/type/status/summary, no direct raw file.
4. User clicks "申請調閱":
   - create `access_requests` record with `pending`.
5. Notify approver (LINE or web):
   - include request summary and risk note.
6. Approver decision:
   - `approved`: set `approved_at`, issue signed URL token with short TTL.
   - `rejected`: set `rejected_at` + decision note.
7. Download attempt is logged:
   - event in `line_event_logs`
   - include request id and result.

## 4) Identity Mapping Rules

Binding rules:
1. one LINE identity may bind to exactly one active internal user per channel+environment.
2. unbound LINE identity can only receive onboarding instructions, not legal data.
3. revoked binding invalidates pending convenience sessions.
4. high-risk actions (approval) require server-side user verification, not LINE display name.

## 5) Audit Logging Rules

Must log:
- all request creation events
- all approval/rejection decisions
- all signed URL issuance attempts
- all download attempts (success/failure)

Retention (proposal):
- keep legal access logs >= 365 days (or tenant policy).

## 6) Minimal RLS Direction (Future)

For all 3 tables:
- same org scope only
- environment_type must match membership environment
- demo/prod strict isolation

`access_requests` add role boundary:
- requester can view own requests
- approver can view requests assigned to self
- legal_admin can view all in org scope

## 7) Non-Goals in Phase 1.5

- no OCR
- no AI legal analysis
- no points/credit charging
- no auto-send external legal letters

