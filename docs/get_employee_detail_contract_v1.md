# get_employee_detail_contract_v1 (Staging)

## Function
`get_employee_detail(employee_id_or_code)`

## Canonical Fields
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
- `avatar_url` (v1 目前固定可為 `null`)

## list vs detail Mapping Difference
- detail 比 list 多：
  - `preferred_locale`
  - `timezone`
  - `employment_type`
  - `manager_name`
  - `direct_reports_count`
- list 比 detail 多（或較常用）：
  - `display_name`
