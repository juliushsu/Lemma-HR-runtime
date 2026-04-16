# Domain / Origin CORS Mapping

更新日期：2026-04-01

## Staging API Domain
- `https://lemma-backend-staging-staging.up.railway.app`

## Staging Allowed Origins（env-controlled）
- Env key: `CORS_ALLOWED_ORIGINS`
- Current value:
  - `https://readdy.ai`
  - `http://localhost:3000`
- 設定格式（CSV）：
  - `CORS_ALLOWED_ORIGINS=https://readdy.ai,http://localhost:3000,https://<future-staging-frontend-domain>`

## CORS Header Policy (/api/*)
- `Access-Control-Allow-Origin: <allowed origin>`
- `Access-Control-Allow-Headers: authorization,content-type`
- `Access-Control-Allow-Methods: GET,POST,PATCH,DELETE,OPTIONS`
- 未在 allow list 的 origin：
  - `OPTIONS` 回 `403`
  - `GET/POST...` 不回 `Access-Control-Allow-Origin`

## Production CORS 收斂方式
- 同樣使用 `CORS_ALLOWED_ORIGINS`（不靠 hardcode）
- 僅放行正式前端網域（建議 1~2 個）
- 禁止 wildcard `*`
- 變更流程：
  1. 更新 production service env `CORS_ALLOWED_ORIGINS`
  2. 重新部署
  3. 驗證 `OPTIONS /api/me` 與 `GET /api/me`（含 Bearer token）

