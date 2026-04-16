# Sprint 2B.1 - Attendance LINE Check-in v1 Proposal

## Goal
- 定義 LINE 打卡的最小可行產品規格與 contract。
- 本文件僅為 proposal，不含 migration/route 實作。

## 1) LINE 打卡流程（Proposal）

1. 員工在 LINE 官方帳號觸發打卡入口（LIFF）。
2. 前端取得 LINE user identity（`line_user_id`）與打卡資料（`check_type`, `checked_at`, optional GPS）。
3. 系統做 identity mapping（LINE user -> 平台 user/employee）。
4. 解析 employee default branch 與 boundary（company default -> branch override）。
5. 進行規則驗證（分店是否啟用、GPS 是否在邊界內、是否重複打卡）。
6. 驗證通過後寫入 canonical `attendance_logs`，`source_type='line_liff'`。
7. 回傳成功/失敗結果給 LINE 前端，並記錄 audit。

## 2) Identity Mapping（LINE user ↔ employee/user）

## 2.1 Mapping key
- primary key: `line_user_id`
- 目標對象：
  - `users.id`
  - `employees.id`

## 2.2 建議 mapping 規則
- 若同一 `line_user_id` 對應多個 employee（跨公司/環境），需透過 scope（org/company/environment）唯一化。
- 若找不到 mapping：
  - 回錯誤 `LINE_IDENTITY_NOT_BOUND`
  - 不寫入 attendance log

## 2.3 建議資料模型（僅 proposal）
- `attendance_line_identities`（提案）
  - `line_user_id`
  - `user_id`
  - `employee_id`
  - `org_id/company_id/environment_type`
  - `is_active`
  - `last_verified_at`

## 3) Branch / GPS Boundary 關聯

## 3.1 Branch 來源
- 優先使用 `employee.branch_id`。
- 若 `employee.branch_id` 為空，可 fallback `employee_assignments` 的 current primary branch。

## 3.2 Boundary resolve 順序
1. company default (`attendance_boundary_settings.branch_id is null`)
2. branch override (`attendance_boundary_settings.branch_id = employee_branch_id`)

## 3.3 GPS 檢核輸出
- 建議寫入 `attendance_logs`：
  - `gps_lat`, `gps_lng`
  - `geo_distance_m`
  - `is_within_geo_range`
  - `branch_id`
  - `source_type='line_liff'`

## 4) Webhook Event Shape（Proposal）

## 4.1 Inbound webhook payload（logical shape）
```json
{
  "provider": "line",
  "event_type": "attendance.check",
  "event_id": "line_evt_xxx",
  "line_user_id": "Uxxxxxxxx",
  "occurred_at": "2026-04-02T09:01:23+08:00",
  "payload": {
    "check_type": "check_in",
    "checked_at": "2026-04-02T09:01:20+08:00",
    "gps_lat": 25.033964,
    "gps_lng": 121.564468,
    "source_ref": "line_msg_xxx"
  },
  "scope_hint": {
    "org_id": "uuid",
    "company_id": "uuid",
    "environment_type": "demo"
  }
}
```

## 4.2 Idempotency
- `event_id` + `line_user_id` 建議作為 webhook 去重 key。
- 重送 webhook 不應產生重複打卡紀錄。

## 5) Canonical Write Target

## 5.1 attendance_logs（主要寫入）
- 寫入欄位建議：
  - scope: `org_id`, `company_id`, `branch_id`, `environment_type`, `is_demo`
  - user: `employee_id`
  - check: `attendance_date`, `check_type`, `checked_at`
  - source: `source_type='line_liff'`, `source_ref`
  - geo: `gps_lat`, `gps_lng`, `geo_distance_m`, `is_within_geo_range`
  - state: `status_code`, `is_valid`, `is_adjusted=false`, `note`

## 5.2 attendance_adjustments（非首寫）
- LINE 流程本身不直接寫 adjustments。
- 若後續人工修正，走既有 adjustment 流程。

## 5.3 audit（提案）
- 建議保存：
  - webhook 原始事件摘要
  - mapping 結果
  - boundary resolve 結果
  - 寫入結果（success/failure + code）

## 6) 權限 / 稽核（Proposal）

## 6.1 權限建議
- 員工本人（經 LINE 綁定）可提交打卡事件，但僅限自身 employee。
- 管理端角色（admin/manager）可讀取結果，不可冒用 LINE 身份提交。

## 6.2 稽核建議
- 每筆 LINE 打卡保留：
  - `event_id`
  - `line_user_id`
  - `employee_id`
  - `resolved_from`
  - `decision`（accepted/rejected）
  - `decision_reason_code`

## 7) 失敗情境（必含）

1. 未綁定
- code: `LINE_IDENTITY_NOT_BOUND`
- 說明：找不到 `line_user_id` 對應 user/employee
- 行為：拒絕寫入 canonical log

2. 超出邊界
- code: `OUT_OF_GEO_BOUNDARY`
- 說明：GPS 距離超過 `resolved_checkin_radius_m`
- 行為（Phase 1 建議）：允許寫入但標記 `is_within_geo_range=false` 並回警示

3. 停用分店/停用出勤
- code: `ATTENDANCE_DISABLED`
- 說明：company 或 location resolved attendance disabled
- 行為：拒絕寫入

4. 重複打卡
- code: `DUPLICATE_CHECK_EVENT`
- 說明：短時間同 employee + 同 check_type + 同 event_id/source_ref 重複
- 行為：冪等回應，不新增第二筆 log

## 8) Phase 標註

## 8.1 Phase 1（先做）
- LINE 打卡最小流程（check-in/check-out）
- identity mapping（單一 employee 綁定）
- branch/boundary resolve
- canonical write to `attendance_logs`
- 基本失敗碼：未綁定、停用、重複、超出邊界
- 基本 audit trail（事件摘要 + 結果）

## 8.2 先不做（後續）
- 多 employee 動態切換綁定 UI
- 複雜排班規則比對（跨日班、彈性班特例）
- 自動補卡申請流程
- 進階風險偵測（GPS spoofing advanced heuristics）
- 外部 API / 檔案上傳匯入整合（另案 Sprint 2B.2+）

## 9) Minimal Contract（Readiness）

## 9.1 Request（logical）
- required:
  - `line_user_id`
  - `check_type`
  - `checked_at`
- optional:
  - `gps_lat`, `gps_lng`
  - `source_ref`
  - `event_id`

## 9.2 Response（logical）
- success:
  - `attendance_log_id`
  - `employee_id`
  - `branch_id`
  - `resolved_from`
  - `is_within_geo_range`
- failure:
  - `error.code`
  - `error.message`
  - `error.details`（例如 boundary distance, disabled reason）

