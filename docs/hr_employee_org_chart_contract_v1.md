# HR Employee Detail + Org Chart Contract v1 (Staging)

## 1) Employee Detail Canonical Contract
Function: `get_employee_detail(employee_id_or_code)`

輸出欄位：
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
- `avatar_url` (nullable, v1 固定可為 `null`)

補充 functions：
- `list_employee_direct_reports(employee_id_or_code)`
- `list_employee_org_relations(employee_id_or_code)`

## 2) Org Chart Derived Contract
組織圖資料來源：
- `employees`
- `manager_employee_id`
- `departments`
- `positions`

規則：
- Org chart 是 derived view，不是 primary edit source。
- primary edit source 在 employee detail / employee edit。
- manager linkage 以 `employees.manager_employee_id` 為唯一匯報關係來源。
- 部門/職位顯示由 `department_id -> departments.department_name`、`position_id -> positions.position_name` 推導。

## 3) Root Rules (v1)
推薦 resolver：
- `list_org_chart_roots(org_id, company_id)`
- `list_org_chart_children(employee_id_or_code)`

root 判定：
- `manager_employee_id is null`，或 manager 不在同 scope（org/company/environment）。

多位 root 排序：
1. `is_managerial = true` 優先
2. `department.sort_order` 由小到大
3. `hire_date` 由早到晚
4. `employee_code` 升冪

## 4) `is_top_executive` / `org_chart_rank` 是否必需
- v1 不必加欄位，可先用上方 rule 推導。
- 若後續有固定董事會/總經理置頂需求，再考慮新增 `org_chart_rank`（非本輪範圍）。

## 5) High-level Data Protection (v1 minimal)
- 高層人員可出現在 org chart（僅顯示組織關係所需欄位）。
- detail 頁與 sensitive fields 應走更嚴格授權（依 `can_read_scope` / `can_write_scope` + route 層權限）。
- v1 最小建議：
  - org chart 僅回傳姓名/職位/匯報關係。
  - sensitive 欄位（薪資、證件、私密聯絡資料）不得由 org chart resolver 回傳。
  - 所有 detail 查詢保留 request actor 與審計軌跡（可沿用既有 audit 方案）。
