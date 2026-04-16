# Canonical Response Contract Cheat Sheet v1

給前端 parser 的唯一基準（snake_case，禁止自創格式）。

## 1) List Endpoint Envelope
```json
{
  "schema_version": "module.resource.list.v1",
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

## 2) Detail Endpoint Envelope
```json
{
  "schema_version": "module.resource.detail.v1",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-01T12:00:00Z"
  },
  "error": null
}
```

## 3) Pagination 標準位置
- 固定在：`data.pagination`
- 固定欄位：
  - `data.pagination.page`
  - `data.pagination.page_size`
  - `data.pagination.total`

## 4) Error 標準位置
```json
{
  "schema_version": "module.resource.xxx.v1",
  "data": {},
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-01T12:00:00Z"
  },
  "error": {
    "code": "MACHINE_READABLE_CODE",
    "message": "human readable message",
    "details": null
  }
}
```

