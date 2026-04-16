# Legal Cases Smoke Sheet

最小驗證目標：避免 `/api/legal/cases*` 空白或 parser 斷裂。

## Scope
- `GET /api/legal/cases`
- `GET /api/legal/cases/:id`

## Request
- Auth: `Authorization: Bearer <access_token>`
- 建議 query（list）：
  - `org_id`
  - `company_id`
  - 可選：`case_type`, `status`, `keyword`

## Expected (List)
- status: `200`
- `schema_version = legal.case.list.v1`
- `error = null`
- `data.items` 為 array（可空，但型別不可錯）
- item 至少含：
  - `id`
  - `case_code`
  - `case_type`
  - `title`
  - `status`

## Expected (Detail)
- status: `200`
- `schema_version = legal.case.detail.v1`
- `error = null`
- `data.legal_case` 存在
- `data.linked_documents` 為 array
- `data.case_events` 為 array

## Failure Cases
- 無 token：`401`
- scope 不符：`403`
- case 不存在：`404` + `error.code = LEGAL_CASE_NOT_FOUND`
- 不可出現 `500`

