# Staging Runtime 實況文件

更新時間：2026-04-01 (Asia/Taipei)

## 1) Staging URL
- Public API Base URL: `https://lemma-backend-staging-staging.up.railway.app`
- Railway service: `lemma-backend-staging`
- Railway environment: `staging`

## 2) 測試帳號
- Auth email: `staging.tester2@lemma.local`
- Auth password: `StagingTest#2026`
- Supabase user_id: `d2408a2a-2aa2-46a9-a5c5-4bf090aad008`
- Membership scope: `admin` + `company` (org/company: production)

## 3) Smoke Pass 清單
以下均以 Bearer JWT 驗證通過（HTTP 200，且資料非空）
- `GET /api/me` -> PASS
- `GET /api/hr/employees` -> PASS
- `GET /api/legal/documents` -> PASS
- `GET /api/legal/documents/:id` -> PASS
- `GET /api/legal/cases` -> PASS
- `GET /api/legal/cases/:id` -> PASS

## 4) 已部署 Route（app/api）
- `GET /api/me`
- `GET /api/hr/employees`
- `POST /api/hr/employees`
- `GET /api/hr/employees/:id`
- `PATCH /api/hr/employees/:id`
- `GET /api/hr/departments`
- `POST /api/hr/departments`
- `GET /api/hr/positions`
- `GET /api/hr/org-chart`
- `GET /api/hr/attendance/logs`
- `POST /api/hr/attendance/check`
- `GET /api/hr/attendance/daily-summary`
- `POST /api/hr/attendance/adjustments`
- `GET /api/legal/documents`
- `POST /api/legal/documents`
- `GET /api/legal/documents/:id`
- `GET /api/legal/documents/:id/versions`
- `GET /api/legal/cases`
- `POST /api/legal/cases`
- `GET /api/legal/cases/:id`
- `GET /api/legal/cases/:id/documents`
- `POST /api/legal/cases/:id/documents`
- `POST /api/legal/storage/upload-url`

## 5) Env Naming（staging）
- `NEXT_PUBLIC_APP_ENV=staging`
- `APP_ENV=staging`
- `NODE_ENV=production`
- `DEPLOY_TARGET=railway-staging`
- `APP_BASE_URL=https://lemma-backend-staging-staging.up.railway.app`
- `SUPABASE_URL=https://eqsgtfnzpznedwusbpda.supabase.co`
- `SUPABASE_ANON_KEY=...`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY=...`
- `SUPABASE_SERVICE_ROLE_KEY=...`
- `LEGAL_DOCUMENTS_BUCKET=legal-documents`
- `HR_DEMO_MODE=false`
- `LC_DEMO_MODE=true`

## 6) 已知限制
- Railway 目前是「CLI 上傳部署」，不是 Git repo 連動（`source.repo = null`）。
- API 一律需要 Bearer JWT；未帶 token 會回 401。
- `/api/me`、HR、Legal 路由均依賴 Supabase Auth + memberships scope；測試時請先登入拿 token。
- 本輪已做最小 RLS 熱修以排除 policy recursion；後續建議補正式 migration 檔固化這些 hotfix。

## 7) 下輪前端可直接串接 Endpoint
- `GET /api/me`
  - schema: `auth.me.v1`
- `GET /api/hr/employees`
  - schema: `hr.employee.list.v1`
- `GET /api/hr/employees/:id`
  - schema: `hr.employee.detail.v1`
- `GET /api/legal/documents`
  - schema: `legal.document.list.v1`
- `GET /api/legal/documents/:id`
  - schema: `legal.document.detail.v1`
- `GET /api/legal/cases`
  - schema: `legal.case.list.v1`
- `GET /api/legal/cases/:id`
  - schema: `legal.case.detail.v1`

前端串接注意
- API envelope 統一讀 `schema_version / data / meta / error`。
- 前端不得直碰 DB，僅透過上述 adapter route。
