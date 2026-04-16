# Legal Detail Response Contract Cheat Sheet v1

給前端 parser 使用，僅針對 detail endpoint：
- `GET /api/legal/documents/:id`
- `GET /api/legal/cases/:id`

## 1) Document Detail
```json
{
  "schema_version": "legal.document.detail.v1",
  "data": {
    "legal_document": {},
    "versions": [],
    "tags": []
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

Parser 重點：
- 主體：`data.legal_document`
- 版本：`data.versions`（array）
- 標籤：`data.tags`（array）

## 2) Case Detail
```json
{
  "schema_version": "legal.case.detail.v1",
  "data": {
    "legal_case": {},
    "linked_documents": [],
    "case_events": []
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "iso_datetime"
  },
  "error": null
}
```

Parser 重點：
- 主體：`data.legal_case`
- 關聯文件：`data.linked_documents`（array）
- 案件事件：`data.case_events`（array）

## 3) Error Shape（共通）
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

