# Leave Request Policy Impact Minimal Contract v1

Status: staging-ready, contract only (submit/approve integration wiring next round).

## 1) Rule Inputs (from Leave Policy Engine)
- `leave_type_code` (from `leave_types.leave_type_code`)
- `requires_attachment` (from `leave_types.requires_attachment`)
- `requires_approval` (from `leave_types.requires_approval`)
- `affects_payroll` (from `leave_types.affects_payroll`)
- `leave_year_mode` (from `leave_policy_profiles.leave_year_mode`)
- `holiday_mode` (from `leave_policy_profiles.holiday_mode`)
- `country_code` (from `leave_policy_profiles.country_code`)

## 2) Submit Stage (minimal impact)
- Resolve active profile by `org_id + company_id + environment_type + effective date`.
- Resolve leave type by `leave_type_code` under active profile.
- Apply:
  - `requires_attachment=true`: submit should require at least one attachment metadata record before final submit.
  - `requires_approval=true`: initial status should be `pending`.
  - `requires_approval=false`: initial status may become `approved` (or auto-approved flow).
  - `affects_payroll`: default `leave_requests.affects_payroll`.

## 3) Approve Stage (minimal impact)
- Approval still follows approver permissions.
- On approve:
  - keep or inherit `affects_payroll` for downstream payroll calculation.
  - record evaluated `leave_type_code` + profile id (recommended future extension).

## 4) Holiday/Year Mode Usage (minimal)
- `country_code + holiday_mode`:
  - used to determine if leave date overlaps official holiday day-off logic.
- `leave_year_mode`:
  - used by entitlement/balance resolver for annual window (calendar/anniversary/custom).

## 5) Suggested Canonical Payload Additions for `leave_requests` submit
- `leave_type_code`
- `policy_profile_id` (optional now, recommended)
- `country_code` (derived, optional now)
- `requires_attachment` (derived snapshot, optional now)
- `requires_approval` (derived snapshot, optional now)
- `affects_payroll` (derived default, already present)
