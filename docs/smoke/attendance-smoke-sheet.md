# Attendance Smoke Sheet

目的：避免前端把 `logs` 與 `summary` 當成同一種資料而誤判。

## Endpoints
- Logs:
  - `GET /api/hr/attendance/logs`
  - `GET /api/hr/attendance-logs` (alias)
- Summary:
  - `GET /api/hr/attendance/daily-summary`
  - `GET /api/hr/attendance-summary` (alias)

## 預期差異（重點）
1. 資料粒度
- Logs：事件級（一筆 = 一次 check_in/check_out 事件）
- Summary：日級（一筆 = 員工某一天彙總）

2. schema_version
- Logs：`hr.attendance.log.list.v1`
- Summary：`hr.attendance.daily_summary.v1`

3. data 結構
- Logs：`data.items` + `data.pagination`
- Summary：`data.items`（目前無 `pagination`）

4. status 語意
- Logs：`status_code` 是事件狀態（如 `late`, `early_leave`）
- Summary：`day_status` 是日彙總狀態，不等於單一 log 的 `status_code`

5. 時間欄位
- Logs：`checked_at`（事件時間）
- Summary：`first_check_in_at` / `last_check_out_at`（日首末打卡）

## Smoke Checklist
1. Logs 回應 200，且 `schema_version=hr.attendance.log.list.v1`
2. Logs `data.pagination.total` 存在，`items[*].check_type` 存在
3. Summary 回應 200，且 `schema_version=hr.attendance.daily_summary.v1`
4. Summary 不應強制讀 `data.pagination`
5. Summary `items[*].day_status` 存在，且可與 logs 的 `status_code` 不同
6. 前端不得用 summary 去回推單筆事件明細

## Failure 判定
- 若前端以 summary parser 解析 logs（或反之）即為 FAIL
- 若前端把 `day_status` 當 `status_code` 顯示即為 FAIL
- 若前端對 summary 強讀 `data.pagination.total` 導致 crash 即為 FAIL

