# Onboarding -> Employee Master Minimal Handoff v1 (Staging)

## 1) Approved Onboarding to employee_id Mapping

Source linkage:
- `employee_onboarding_invitations.employee_id`
- `employee_onboarding_intake.employee_id`
- related tables (`documents/signatures/contract_deliveries`) also carry `employee_id`

Approval checkpoint:
- when onboarding reaches `onboarding_status='approved'`, `employee_id` should already be resolved.

## 2) Minimal Conversion Contract

Input (from onboarding approved intake):
- invitation: `invitation_id`, `employee_id`, `org_id`, `company_id`, `environment_type`
- intake core:
  - `full_name_local`
  - `full_name_latin`
  - `birth_date`
  - `nationality_code`
  - `phone`
  - `email`
  - `emergency_contact_name`
  - `emergency_contact_phone`
  - `preferred_language` (invitation)

Employee master update target (minimal):
- `employees.full_name_local`
- `employees.full_name_latin`
- `employees.birth_date`
- `employees.nationality_code`
- `employees.mobile_phone` (from intake.phone)
- `employees.personal_email` (from intake.email, optional mapping rule)
- `employees.preferred_locale` (from invitation.preferred_language)
- `employees.emergency_contact_name`
- `employees.emergency_contact_phone`

## 3) Should Be Carried from Onboarding

Carry-in fields:
- name (local/latin)
- birth date
- nationality
- contact baseline
- emergency contact baseline
- preferred language

## 4) Should Be Completed in HR Employee Detail

HR post-onboarding completion:
- `department_id/department_name`
- `position_id/position_title`
- `manager_employee_id`
- `employment_type`
- `employment_status`
- `hire_date`
- `timezone`
- language skills (in `employee_language_skills`)

## 5) Consistency Rule

Current behavior in staging:
- onboarding views display invitation/intake snapshots (`invitee_name`, intake names), not live-joined employee names.
- employee master updates do not overwrite onboarding snapshot fields automatically.

Recommendation:
- keep onboarding as immutable intake snapshot.
- employee detail uses canonical live employee record.
- UI should label onboarding data as \"submitted snapshot\" when values differ from current employee master.
