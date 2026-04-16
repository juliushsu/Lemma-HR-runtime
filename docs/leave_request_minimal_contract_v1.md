# Leave Request Minimal Contract v1 (Proposal Only)

Status: proposal only, no migration in this round.

## 1) Canonical fields
- `leave_request_id`
- `employee_id`
- `org_id`
- `company_id`
- `leave_type`
- `start_date`
- `end_date`
- `start_time` (nullable)
- `end_time` (nullable)
- `duration_hours` (nullable)
- `duration_days` (nullable)
- `reason`
- `approver_user_id`
- `approval_status`
- `approved_at` (nullable)
- `rejected_at` (nullable)
- `rejection_reason` (nullable)
- `affects_payroll`
- `created_at`
- `updated_at`

## 2) Minimal leave type enum (v1)
- `annual_leave`
- `sick_leave`
- `personal_leave`
- `unpaid_leave`
- `maternity_leave`
- `bereavement_leave`
- `official_leave`
- `other`

## 3) Approval status enum (v1)
- `draft`
- `submitted`
- `approved`
- `rejected`
- `cancelled`

## 4) Future integration points
- Attendance linkage:
  - approved request should generate attendance-exception window for date/time range.
  - attendance summary should exclude approved leave from missing/late checks.
- Payroll linkage:
  - use `affects_payroll` + `leave_type` + approved duration for downstream payroll calculation.
  - payroll engine should consume leave ledger snapshot, not mutate leave request records.

## 5) LINE form canonical naming (for request payload)
- `employee_code`
- `leave_type`
- `start_date`
- `end_date`
- `start_time`
- `end_time`
- `duration_hours`
- `duration_days`
- `reason`
- `locale`
- `source_type` (`line`)
- `source_ref` (line event/message id)

## 6) MVP attachment decision
- Recommended: yes, but minimal and optional.
- Minimal fields (proposal):
  - `has_attachment` boolean
  - `attachment_count` int
- Storage should reuse private bucket + signed URL policy pattern.

## 7) approval_logs table decision
- Recommended: yes, separate table in next phase.
- Reason:
  - avoid overwriting single status timeline.
  - keep approver traceability and policy audit.
- Minimal log fields (proposal):
  - `log_id`, `leave_request_id`, `action`, `actor_user_id`, `from_status`, `to_status`, `note`, `created_at`.
