# HR Employee Master v2 Contract (Staging)

## 1) Scope
最小擴充 employee detail/edit，使主檔不只停留在任職資訊。

## 2) New/Confirmed Editable Fields
- names
  - `full_name_local`
  - `full_name_latin`
- identity/basic profile
  - `gender`
  - `nationality_code`
  - `birth_date`
- locale
  - `preferred_locale`
  - `timezone`
- emergency contacts
  - `emergency_contact_name`
  - `emergency_contact_phone`
- existing employment/organization
  - `department_id` / `department_name`
  - `position_id` / `position_title`
  - `manager_employee_id`
  - `employment_type`
  - `employment_status`
  - `hire_date`

## 3) Write Function
`update_employee_profile(payload_jsonb)`

Response fields (v2):
- `employee_id`
- `employee_code`
- `display_name`
- `full_name_local`
- `full_name_latin`
- `gender`
- `nationality_code`
- `birth_date`
- `preferred_locale`
- `timezone`
- `employment_type`
- `employment_status`
- `department_name`
- `position_title`
- `manager_employee_id`
- `manager_name`
- `direct_reports_count`
- `hire_date`
- `emergency_contact_name`
- `emergency_contact_phone`
- `avatar_url`
- `updated_at`

## 4) Detail Function
`get_employee_detail(employee_id_or_code)` now includes:
- existing detail fields
- plus `display_name`, `gender`, `nationality_code`, `birth_date`,
  `work_email`, `personal_email`, `mobile_phone`,
  `emergency_contact_name`, `emergency_contact_phone`

## 5) Spoken Language Model Recommendation
Option A: JSONB on `employees` (`language_skills jsonb`)
- Pros: simplest migration, low initial cost
- Cons: validation/query/index harder, weak cross-record consistency

Option B: separate table `employee_language_skills`
- Recommended for v2
- Suggested columns:
  - `id`, `org_id`, `company_id`, `employee_id`
  - `language_code`
  - `proficiency_level` (`basic|conversational|business|native`)
  - `is_primary`
  - `environment_type`, `is_demo`, `created_at`, `updated_at`, `created_by`, `updated_by`

Reason:
- aligns with existing canonical relational model
- easier filtering (e.g. multilingual staffing)
- cleaner future integration with onboarding / assignment / compliance use cases

## 6) Sensitive / Restricted Fields (v2)
- High sensitivity (restricted read):
  - `birth_date`
  - `mobile_phone`
  - `personal_email`
  - `emergency_contact_name`
  - `emergency_contact_phone`
- Medium sensitivity:
  - `nationality_code`
  - `gender`
- Generally non-sensitive:
  - `full_name_local`
  - `full_name_latin`
  - `preferred_locale`
  - `timezone`
