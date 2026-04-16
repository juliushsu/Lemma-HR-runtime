# HR Org Chart Tree Handoff v1 (Staging)

## Function
`get_org_chart_tree(org_id, company_id)`

## Response Shape
- `employee_id`
- `employee_code`
- `full_name_local`
- `full_name_latin`
- `department_name`
- `position_title`
- `manager_employee_id`
- `employment_status`
- `is_root`
- `has_children`
- `direct_reports_count`
- `node_type` (`root` | `manager` | `staff`)
- `depth` (frontend 可映射成 `level`)
- `root_employee_id`
- `sort_path`

## Node Rules
- `is_root=true` => `node_type='root'`
- `is_root=false` 且 `direct_reports_count>0` => `node_type='manager'`
- `is_root=false` 且 `direct_reports_count=0` => `node_type='staff'`

## Real-time Reflection Rule
- 組織圖由 employee master 即時計算（derived resolver）。
- 當 `update_employee_profile` 更新 `manager_employee_id` 後，`get_org_chart_tree` 會在下一次查詢立即反映，不需額外同步表。
