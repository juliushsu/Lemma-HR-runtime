# Frontend API Handoff (Quick)

## Envelope（共通）
```json
{
  "schema_version": "string",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

## 1) `GET /api/me`
- `schema_version`: `auth.me.v1`
- `data` keys:
  - `user`
  - `memberships`
  - `current_org`
  - `current_company`
  - `locale`
  - `environment_type`
- query params: 無

## 2) `GET /api/hr/employees`
- `schema_version`: `hr.employee.list.v1`
- `data` keys:
  - `items[]`
  - `pagination` (`page`, `page_size`, `total`)
- item keys (常用):
  - `id`, `employee_code`, `display_name`
  - `department`, `position`, `manager`
  - `employment_type`, `employment_status`, `hire_date`
- query params:
  - `org_id`, `company_id`, `branch_id`
  - `keyword`, `department_id`, `position_id`
  - `employment_status`, `employment_type`
  - `page`, `page_size`, `sort_by`, `sort_order`

## 3) `GET /api/legal/documents`
- `schema_version`: `legal.document.list.v1`
- `data` keys:
  - `items[]`
- item keys (常用):
  - `id`, `title`, `document_type`
  - `counterparty_name`, `signing_status`
- query params:
  - `org_id`, `company_id`, `branch_id`
  - `keyword`, `document_type`, `signing_status`
  - `page`, `page_size`, `sort_by`, `sort_order`

## Error Shape
```json
{
  "schema_version": "xxx.v1",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": {
    "code": "MACHINE_READABLE_CODE",
    "message": "human readable message",
    "details": null
  }
}
```

## Empty Result 範例

### `/api/hr/employees` 空資料
```json
{
  "schema_version": "hr.employee.list.v1",
  "data": {
    "items": [],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 0
    }
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-01T12:00:00Z"
  },
  "error": null
}
```

### `/api/legal/documents` 空資料
```json
{
  "schema_version": "legal.document.list.v1",
  "data": {
    "items": []
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-01T12:00:00Z"
  },
  "error": null
}
```
