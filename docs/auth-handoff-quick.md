# Auth Handoff (Quick)

## 1) Staging 測試帳號
- email: `staging.tester2@lemma.local`
- password: `StagingTest#2026`
- 用途：staging smoke / 前端串接驗證

## 2) Login endpoint / SDK usage 原則
- 建議：前端使用 Supabase Auth SDK 登入（不要自建中介 auth）
- `signInWithPassword` 成功後取得 `access_token`
- 呼叫 Lemma API 時一律帶：`Authorization: Bearer <access_token>`
- 前端只打 canonical API：`/api/me`、`/api/hr/*`、`/api/legal/*`

## 3) `/api/me` 登入後預期行為
- 未帶 token：`401`
- 帶有效 token：`200`
- `schema_version = auth.me.v1`
- `data` 內應可讀到：
  - `user`
  - `memberships`
  - `current_org`
  - `current_company`
  - `locale`
  - `environment_type`

## 4) `401 / 403` 預期處理
- `401 Unauthorized`
  - 視為未登入或 token 過期
  - 前端動作：清 session、導回登入、可提示「請重新登入」
- `403 Forbidden`
  - 視為已登入但權限不足（scope/role 不符）
  - 前端動作：顯示無權限頁或 toast，不要重導登入

