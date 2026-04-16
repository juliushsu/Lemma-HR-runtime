# Owner Session Shape (Quick)

## `/api/me` shape notes
- `data.memberships[0]` 是 runtime scope 來源。
- `data.current_org` 由 `memberships[0].org_id` 解析。
- `data.current_company` 只有在 `memberships[0].company_id` 有值時才會查詢；否則回 `null`。

## Owner / org-scope interpretation
- 若 owner membership 是 `scope_type='org'` 且 `company_id=null`：
  - `data.current_company = null` 屬於預期行為。
- 若 owner membership 帶 company_id：
  - `data.current_company` 應回公司物件。

## Frontend requirement
- 前端必須對 `data.current_company` 做 null-safe 處理（必須）。

## 2026-04-03 sanity note
- 帳號 `juliushsu@gmail.com` 實測可通過 Auth，但 `/api/me` 回傳 `memberships=[]`，因此 `role/scope/current_org/current_company` 皆為 `null`。

## 2026-04-03 P0 repair result
- 已補齊 `public.users` 與 `memberships`（`role=owner`, `scope_type=org`, production）。
- `/api/me` 修復後：
  - `data.user != null`
  - `data.memberships.length = 1`
  - `data.current_org != null`
  - `data.current_company != null`
