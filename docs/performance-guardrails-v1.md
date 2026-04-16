# Performance Guardrails v1

更新日期：2026-04-01
範圍：`/api/me`、`/api/hr/*`、`/api/legal/*`

## 1) API 預設 `page_size`
- 預設：`20`
- 適用：所有 list API（如 employees/documents/cases/logs）

## 2) API 最大 `page_size`
- 最大：`100`
- 超過 `100`：後端強制降為 `100`（或回 `400`，二選一但需全專案一致）

## 3) 搜尋 debounce 建議（前端）
- 文字搜尋：`300ms`（建議）
- 若為高成本查詢（跨多欄位）：`400~500ms`
- 輸入長度 `< 2` 時不送 keyword query（可選但建議）

## 4) 必備 Index 欄位
- 通用 scope：`(org_id, company_id, environment_type)`
- HR employees list：`employee_code`, `employment_status`, `department_id`, `position_id`
- Attendance logs：`(org_id, company_id, employee_id, attendance_date)`, `(org_id, company_id, checked_at)`
- Legal documents list：`document_type`, `signing_status`, `created_at`
- Legal cases list：`case_type`, `status`, `created_at`

## 5) 前端併發請求上限
- 同一畫面初次載入：主 API 併發最多 `3` 支
- 超過 `3` 支時：採序列或分段載入（首屏必要資料優先）
- 禁止同時重複打同一 endpoint（需 request dedupe）

## 6) Staging Smoke 後加一個簡易 Response Time 檢查
- 每次 smoke 至少檢查：
  - `GET /api/me`
  - `GET /api/hr/employees`
  - `GET /api/legal/documents`
- 目標（staging）
  - p50 < `300ms`
  - p95 < `1000ms`
- 最低做法：`curl -w` 紀錄 `time_total`，連續打 `5` 次取 p50/p95（不需先上 APM）

