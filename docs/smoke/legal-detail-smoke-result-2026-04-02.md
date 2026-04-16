# Legal Detail Smoke Result (2026-04-02)

Domain:
- `https://lemma-backend-staging-staging.up.railway.app`

Checked at:
- `2026-04-02T03:08:32Z`

## 1) demo.admin@lemma.local

List:
- `GET /api/legal/documents` -> `200`, `items.length=0`
- `GET /api/legal/cases` -> `200`, `items.length=0`

Detail:
- document detail: N/A（list 為空，無可測 id）
- case detail: N/A（list 為空，無可測 id）

結論：
- 目前 demo scope 沒有 legal demo seed，因此 detail 無法以 demo.admin 驗證。

## 2) staging.superadmin@lemma.local

List:
- `GET /api/legal/documents` -> `200`, `items.length=2`
- `GET /api/legal/cases` -> `200`, `items.length=2`

Detail（以首筆 id 驗證）：
- `GET /api/legal/documents/a0000000-0000-0000-0000-000000000001`
  - status: `200`
  - `schema_version=legal.document.detail.v1`
  - `data.legal_document` exists
  - `data.versions.length=1`
  - `data.tags.length=2`

- `GET /api/legal/cases/a2000000-0000-0000-0000-000000000001`
  - status: `200`
  - `schema_version=legal.case.detail.v1`
  - `data.legal_case` exists
  - `data.linked_documents.length=1`
  - `data.case_events.length=2`

## Overall
- `/api/legal/documents/:id`：PASS（production/staging.superadmin scope）
- `/api/legal/cases/:id`：PASS（production/staging.superadmin scope）
- demo.admin scope：目前 list 為空，屬資料面（seed）而非 route 錯誤

