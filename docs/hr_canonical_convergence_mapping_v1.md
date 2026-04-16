# HR Canonical Convergence Mapping v1 (Staging)

## 1) Canonical Source vs Derived

Canonical source (`public.employees`):
- `employee_id` (`id`)
- `employee_code`
- `display_name`
- `full_name_local`
- `full_name_latin`
- `preferred_locale`
- `timezone`
- `employment_type`
- `employment_status`
- `department_id`
- `position_id`
- `manager_employee_id`
- `hire_date`
- `gender`
- `nationality_code`
- `birth_date`
- `emergency_contact_name`
- `emergency_contact_phone`

Derived display fields:
- `department_name` := `employees.department_id -> departments.department_name`
- `position_title` := `employees.position_id -> positions.position_name`
- `manager_name` := `employees.manager_employee_id -> employees(full_name/display_name)`
- `direct_reports_count` := count of employees where `manager_employee_id = current employee`
- org chart `is_root/has_children/node_type/depth/sort_path` := derived from manager relation

## 2) list/detail/tree Field Semantics

`get_employee_detail`:
- canonical + derived mix
- includes personal/profile + org mapping + relation counts

`list_employees`:
- current staging DB has no dedicated `public.list_employees(...)` function.
- current contract is documentation-level (`docs/list_employees_contract_v1.md`).
- expected list output is a projection of canonical + selected derived display fields.

`get_org_chart_tree`:
- canonical identity + derived hierarchy fields
- not a primary edit source; only relationship projection

## 3) list-only / detail-only

List-only (expected):
- lightweight display bundle (e.g., `display_name`, basic status)

Detail-only:
- `gender`
- `birth_date`
- `emergency_contact_*`
- `direct_reports_count`
- `manager_name`

Shared canonical core:
- `employee_id`
- `employee_code`
- `full_name_local`
- `full_name_latin`
- `employment_status`
- `department_name`
- `position_title`

## 4) Language Skills Exposure

Canonical source:
- `employee_language_skills` (separate table)

Current exposure:
- not embedded in `get_employee_detail` yet
- read via `list_employee_language_skills(employee_id_or_code)`
