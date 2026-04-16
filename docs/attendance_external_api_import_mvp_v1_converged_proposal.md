# Sprint 2B.7 - External API Import MVP 收斂版 Proposal（No Implementation）

## Goal
- 將 external API import 從概念提案收斂為可施工的 Phase 1 規格。
- 本文件僅為 proposal，不含 migration / route / UI 實作。

## Phase 1 Scope（Frozen）

### 明確包含
- source registration
- credential/config
- inbound payload validation
- preview/normalize
- confirm write

### 明確不做
- payroll/shift integration
- OCR/AI auto-correction
- provider marketplace

## 1) 最小流程（Phase 1）

1. `source registration`
- 在 `attendance_source_registry`（proposal）註冊一個 `source_type='external_api'` 來源。
- scope 必綁定：`org_id / company_id / environment_type`，可選 `branch_id`。

2. `credential/config`
- 設定最小 credential/config（建議支援 `hmac` 或 `bearer_token`）。
- 設定 `is_enabled` 與 `feature_gate_key=attendance.external_api.enabled`。

3. `inbound payload validation`
- 先驗證來源身分（signature/token）。
- 再做欄位檢查、datetime 檢查、idempotency 檢查。
- 不合法資料不直接寫 canonical，先進 staging preview 結果。

4. `preview/normalize`
- 針對每筆 inbound record 產出 normalized 結果：
  - `valid`（可匯入）
  - `error`（不可匯入，附錯誤碼）
- 提供人工覆核入口（只針對 error 列）。

5. `confirm write`
- 僅把 `valid` 或「修正後核准」的資料寫入 canonical。
- 寫入完成後更新 import batch 狀態與統計數。

## 2) Canonical Write Target（Phase 1）

### 2.1 `attendance_logs`（必做）
- confirm 後落地至 `attendance_logs`。
- `source_type` 固定為 `external_api`（Phase 1 凍結）。
- `source_ref` 建議寫入 `event_id` 或 provider event key，供追蹤與去重。

### 2.2 `attendance_adjustments`（有人工修正時）
- 當 reviewer 修正值後核准匯入，需同步寫 `attendance_adjustments`。
- 保留原始值、修正值、reason、reviewer 與時間戳。

### 2.3 支援實體（proposal）
- `attendance_import_batches`
- `attendance_import_rows`（或同等 staging rows）
- `import_review_tasks`（若需最小人工覆核佇列）

## 3) 最小必要 Payload（Phase 1）

### 3.1 Required fields
- `external_employee_ref` 或 `employee_code`（至少提供一個）
- `attendance_date`
- `check_type`
- `checked_at`
- `event_id`（或 `source_ref`）

### 3.2 Recommended optional fields
- `branch_ref` 或 `branch_id`
- `timezone`
- `note`
- `raw_payload`（原始事件快照）

### 3.3 Minimal payload example
```json
{
  "event_id": "evt_20260402_0001",
  "employee_code": "EMP-0001",
  "external_employee_ref": "partner-88912",
  "attendance_date": "2026-04-02",
  "check_type": "check_in",
  "checked_at": "2026-04-02T08:59:20+08:00",
  "branch_ref": "taipei-hq"
}
```

## 4) Validation / Normalize 規則（Phase 1）

### 4.1 Employee resolve order
1. `employee_code` 直接對應
2. `external_employee_ref` 對應 mapping（若已建立）
3. 仍無法對應則 `EMPLOYEE_UNRESOLVED`

### 4.2 Branch resolve order
1. payload `branch_id`（可直接命中）
2. payload `branch_ref`（透過 mapping 命中）
3. employee default branch
4. 仍無法對應則 `BRANCH_UNRESOLVED`

### 4.3 Datetime normalize
- `checked_at` 必須可解析為合法 datetime。
- `attendance_date` 可驗證與 `checked_at` 一致性（允許時區換日規則）。

### 4.4 Idempotency
- 以 `(source_registry_id, event_id)` 為第一優先去重鍵。
- 若 `event_id` 缺失，退化為 `(employee, check_type, checked_at, source_ref)`。

## 5) Confirm Write 行為（Phase 1）

1. 僅匯入 `valid` 或「corrected_and_approved」列。  
2. 每列寫入 `attendance_logs.source_type='external_api'`。  
3. 修正列同步寫 `attendance_adjustments`。  
4. 批次狀態至少支援：
- `preview_ready`
- `importing`
- `imported`
- `partially_imported`
- `failed`

## 6) 錯誤情境（Phase 1 必含）

1. `EMPLOYEE_UNRESOLVED`
- 找不到 employee（`employee_code`/`external_employee_ref` 皆無法對應）。

2. `INVALID_SIGNATURE_OR_AUTH`
- HMAC 驗章失敗、token 不合法、來源停用等認證問題。

3. `INVALID_DATETIME`
- `checked_at` 不可解析或格式不合法。

4. `DUPLICATE_EXTERNAL_EVENT`
- 同一來源重複送入相同 `event_id`，或去重鍵命中已存在事件。

5. `BRANCH_UNRESOLVED`
- 無法由 payload 或 employee default branch 解析出有效 branch。

## 7) Phase 切分

### Phase 1（本文件凍結）
- External source registration + enable/disable
- Credential/config（hmac 或 bearer 最小集合）
- Inbound validation + preview/normalize + confirm write
- Canonical write：
  - `attendance_logs`（`source_type=external_api`）
  - `attendance_adjustments`（修正時）
- 五類核心錯誤碼（employee/auth/datetime/duplicate/branch）

### Phase 1.1
- 多 provider mapping template（欄位映射配置化）
- Retry / replay policy（含死信佇列策略）
- 匯入品質統計與 dashboard（accepted/rejected/error ratio）
- 更完整 timezone 與跨日班規則

### Later
- 雙向 callback/ack 協議
- Connector marketplace
- 自動品質評分與異常偵測

## 8) Non-goals（This Round）
- 不做 migration
- 不做 route
- 不碰 payroll / shift
