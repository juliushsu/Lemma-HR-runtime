# list_employees_contract_v1 (Staging)

## Purpose
定義 `/api/hr/employees` 的最小穩定欄位契約，供前端 list 頁使用。

## Canonical Fields
- `employee_id`
- `employee_code`
- `display_name`
- `full_name_local`
- `full_name_latin`
- `department_name`
- `position_title`
- `employment_status`
- `manager_employee_id`
- `hire_date` (nullable)

## Notes
- list 以「列表可讀性」為主，不保證回傳 detail enrichment（如 `manager_name`、`direct_reports_count`）。
- `avatar_url` 在 v1 可為 `null` 或不回傳。
