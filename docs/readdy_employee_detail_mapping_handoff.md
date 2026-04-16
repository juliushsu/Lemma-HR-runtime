# Employee Detail Mapping Handoff (for Readdy)

## 1. 問題摘要
- employee list 正常
- employee detail 部分欄位空白
- 以 `DEMO-004` 實測，detail endpoint 已回完整值
- 結論：前端 mapping 問題，不是 seed 問題

## 2. Endpoint 與實測 Payload

Canonical read source:
- `get_employee_detail(employee_id_or_code)`

### DEMO-004（完整 JSON）
```json
{
  "employee_id": "71000000-0000-0000-0000-000000000104",
  "employee_code": "DEMO-004",
  "full_name_local": "鈴木 花子",
  "full_name_latin": "Hanako Suzuki",
  "preferred_locale": "ja",
  "timezone": "Asia/Tokyo",
  "employment_type": "full_time",
  "employment_status": "active",
  "department_name": "Demo Headquarters",
  "position_title": "HR Specialist",
  "manager_employee_id": "71000000-0000-0000-0000-000000000102",
  "manager_name": "佐藤 健（さとう けん）",
  "direct_reports_count": 0,
  "hire_date": "2026-01-14T16:00:00.000Z",
  "avatar_url": null,
  "display_name": "Emily Johnson",
  "gender": "female",
  "nationality_code": "JP",
  "birth_date": "1997-08-19T16:00:00.000Z",
  "work_email": "demo.emily@lemma.local",
  "personal_email": null,
  "mobile_phone": "+886900100004",
  "emergency_contact_name": "鈴木 太郎",
  "emergency_contact_phone": "+819012345678"
}
```

### EMP-0004（完整 JSON）
```json
{
  "employee_id": "70000000-0000-0000-0000-000000000004",
  "employee_code": "EMP-0004",
  "full_name_local": "李娜",
  "full_name_latin": "Li Na",
  "preferred_locale": "zh-TW",
  "timezone": "Asia/Taipei",
  "employment_type": "full_time",
  "employment_status": "active",
  "department_name": "Human Resources",
  "position_title": "HR Specialist",
  "manager_employee_id": "70000000-0000-0000-0000-000000000002",
  "manager_name": "佐藤健",
  "direct_reports_count": 0,
  "hire_date": "2025-02-28T16:00:00.000Z",
  "avatar_url": null,
  "display_name": "Li Na",
  "gender": null,
  "nationality_code": "CN",
  "birth_date": null,
  "work_email": "li.na@lemma.local",
  "personal_email": "li.na.personal@example.com",
  "mobile_phone": "+886900000004",
  "emergency_contact_name": null,
  "emergency_contact_phone": null
}
```

## 3. 欄位 Mapping 對照表

| UI 區塊 | 前端顯示欄位名稱 | canonical source field | DEMO-004 是否有值 | EMP-0004 是否有值 | null 原因 |
|---|---|---|---|---|---|
| Header | Employee Code | `employee_code` | 是 | 是 | - |
| Header | Local Name | `full_name_local` | 是 | 是 | - |
| Header | Latin Name | `full_name_latin` | 是 | 是 | - |
| Basic Profile | Gender | `gender` | 是 | 否 | seed 缺 |
| Basic Profile | Nationality | `nationality_code` | 是 | 是 | - |
| Basic Profile | Birth Date | `birth_date` | 是 | 否 | seed 缺 |
| Job Info | Department | `department_name` | 是 | 是 | relation 正常 |
| Job Info | Position | `position_title` | 是 | 是 | relation 正常 |
| Job Info | Employment Type | `employment_type` | 是 | 是 | - |
| Job Info | Employment Status | `employment_status` | 是 | 是 | - |
| Job Info | Hire Date | `hire_date` | 是 | 是 | - |
| Preferences | Preferred Locale | `preferred_locale` | 是 | 是 | - |
| Preferences | Timezone | `timezone` | 是 | 是 | - |
| Org Relation | Manager Name | `manager_name` | 是 | 是 | root 時才可能為 null（正常現象） |
| Org Relation | Direct Reports | `direct_reports_count` | 是（0） | 是（0） | - |
| Emergency | Emergency Contact Name | `emergency_contact_name` | 是 | 否 | seed 缺 |
| Emergency | Emergency Contact Phone | `emergency_contact_phone` | 是 | 否 | seed 缺 |

## 4. Flat Field 優先規則
- `department_name` 優先（不要先猜 `department.name` nested）
- `position_title` 優先（不要先猜 `position.title` nested）
- `manager_name` 優先（不要先猜 `manager.full_name` nested）
- `preferred_locale` 優先（不要先猜 `locale` / `language` 自訂欄位）

## 5. 日期顯示注意事項
- `hire_date` / `birth_date` 前端請用 date-only 顯示，避免 UTC 看起來前一天。

## 6. 給 Readdy 的結論
「若 DEMO-004 在頁面上仍顯示空白，屬前端 mapping / parser / props 傳遞問題，不是 seed 問題。」
