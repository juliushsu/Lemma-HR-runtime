# HR Employee Profile Write Contract v1 (Staging)

## Function
`update_employee_profile(payload_jsonb)`

## Purpose
提供 employee detail / edit 頁最小可編輯寫入層，不擴 schema。

## Supported Input Fields (v1)
- identity
  - `employee_id_or_code` (required; 可傳 UUID 或 employee_code)
  - `org_id` (optional, for disambiguation)
  - `company_id` (optional, for disambiguation)
  - `environment_type` (optional, for disambiguation)
- editable profile
  - `department_id` or `department_name`
  - `position_id` or `position_title`
  - `manager_employee_id`
  - `employment_type`
  - `employment_status`
  - `preferred_locale`
  - `timezone`
  - `hire_date`
- audit
  - `actor_user_id` (optional when auth.uid() exists)

## Validation Rules
- employee ref 必填。
- `manager_employee_id` 不可等於本人。
- manager / department / position 必須在同 org/company/environment scope。
- `department_name` / `position_title` 若多筆同名，回 `*_AMBIGUOUS`。

## Return
JSON object（canonical subset）:
- `employee_id`
- `employee_code`
- `full_name_local`
- `full_name_latin`
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
- `avatar_url`
- `updated_at`

## Error Codes (v1)
- `EMPLOYEE_REF_REQUIRED`
- `EMPLOYEE_NOT_FOUND`
- `EMPLOYEE_CODE_AMBIGUOUS`
- `DEPARTMENT_NOT_FOUND` / `DEPARTMENT_NAME_AMBIGUOUS` / `DEPARTMENT_SCOPE_MISMATCH`
- `POSITION_NOT_FOUND` / `POSITION_TITLE_AMBIGUOUS` / `POSITION_SCOPE_MISMATCH`
- `MANAGER_EMPLOYEE_ID_INVALID` / `MANAGER_SELF_NOT_ALLOWED` / `MANAGER_SCOPE_MISMATCH`
- `ACTOR_USER_REQUIRED` / `ACTOR_USER_MISMATCH`
