# Sprint 2B.4 - Attendance Source Registry v1 Proposal

## Goal
- 建立三種出勤來源（`line` / `external_api` / `manual_upload`）的統一管理模型。
- 提供最小 canonical schema proposal，讓來源啟用、設定、稽核、匯入批次與人工覆核可一致治理。
- 本文件為 proposal only：不含 migration、不含 route、不卡 payroll/shift。

## 1) Source Registry Canonical Model

### 1.1 Canonical entity: `attendance_source_registry`（proposal）
- 用途：
  - 統一管理每個 scope 內可用的出勤來源。
  - 管控 enable/disable、配置版本、feature gating。
  - 作為 audit / import / review 流程的上游控制面。
- canonical key:
  - `org_id`
  - `company_id`
  - `branch_id`（nullable，`null` 表示 company-level default）
  - `environment_type`
  - `source_type`

### 1.2 Proposed fields（minimal）
- identity/scope:
  - `id`
  - `org_id`
  - `company_id`
  - `branch_id` (nullable)
  - `environment_type`
  - `is_demo`
- source:
  - `source_type` (`line` | `external_api` | `manual_upload`)
  - `display_name`
  - `description`
- control:
  - `is_enabled`
  - `enabled_from`
  - `disabled_at`
  - `disable_reason`
- config:
  - `config_json` (jsonb)
  - `config_version` (int)
  - `last_validated_at`
- governance:
  - `feature_gate_key`（例如 `attendance.line.enabled`）
  - `rollout_stage`（`pilot` / `ga` / `paused`）
  - `created_by`, `updated_by`, `created_at`, `updated_at`

## 2) Source Type Definition (v1)

### 2.1 `line`
- 來源：LINE webhook / LIFF check-in。
- canonical write target：`attendance_logs`（`source_type='line'`）。
- 依賴：identity binding、branch/GPS boundary、idempotency。

### 2.2 `external_api`
- 來源：第三方系統 API 匯入。
- canonical write target：`attendance_logs`（`source_type='import'` 或未來擴充 `external_api`）。
- 依賴：import batch、mapping、validation/review。

### 2.3 `manual_upload`
- 來源：CSV/Excel 上傳 + 人工校正。
- canonical write target：`attendance_logs`（`source_type='manual'` 或 `import` with channel metadata）。
- 依賴：import batch、review queue、核准流程。

## 3) Enable / Disable Governance

### 3.1 Resolve order（proposal）
1. `company-level` source registry (`branch_id is null`)
2. `branch-level override` source registry (`branch_id = target branch`)
3. 若無任一設定，視為 `disabled`（保守預設）

### 3.2 Runtime behavior（proposal）
- `is_enabled=false`：
  - 拒絕來源輸入（含 webhook/import/upload ingest）。
  - 回傳來源停用錯誤碼（例如 `ATTENDANCE_SOURCE_DISABLED`）。
  - audit 必留 `failure_reason`。
- `is_enabled=true`：
  - 允許進入來源特定流程（line / import / review）。

## 4) Config Shape Proposal（JSON）

### 4.1 `line` config shape（proposal）
```json
{
  "channel_id": "string",
  "webhook_enabled": true,
  "allow_check_in": true,
  "allow_check_out": true,
  "require_geo": true,
  "duplicate_window_seconds": 120,
  "locale_fallback": "en"
}
```

### 4.2 `external_api` config shape（proposal）
```json
{
  "provider_name": "PartnerHR",
  "auth_mode": "hmac",
  "ip_allowlist": ["203.0.113.0/24"],
  "max_batch_size": 5000,
  "idempotency_key_field": "event_id",
  "default_branch_resolution": "employee_default_branch"
}
```

### 4.3 `manual_upload` config shape（proposal）
```json
{
  "allowed_file_types": ["csv", "xlsx"],
  "max_rows_per_file": 10000,
  "require_reviewer": true,
  "auto_approve_when_no_error": false,
  "template_version": "v1"
}
```

## 5) Relation with Audit / Import Batch / Review Flow

### 5.1 Audit relation
- `attendance_source_registry` 作為 audit 上游配置快照來源。
- 建議每筆來源事件保留：
  - `source_registry_id`
  - `source_type`
  - `is_enabled_at_event_time`
  - `config_version_at_event_time`
  - `decision` / `failure_reason`

### 5.2 Import batch relation（external_api / manual_upload）
- 每個 `attendance_import_batches` 應綁定：
  - `source_registry_id`
  - `source_type`
  - `config_version`
- 便於回溯：同一批次採用哪份來源設定。

### 5.3 Review flow relation
- `attendance_import_records_staging` / review task 應可追到：
  - `batch_id -> source_registry_id -> source config`
- 人工覆核結果應保留：
  - reviewer
  - action (`approved` / `rejected` / `corrected_and_approved`)
  - reason

## 6) Relation with Org / Company / Branch / Feature Gating

### 6.1 Scope policy
- 強制 scope 欄位：
  - `org_id`, `company_id`, `environment_type`
  - `branch_id`（可為 null）
- 禁止跨 scope 套用來源配置。

### 6.2 Feature gating policy
- 以 `feature_gate_key` 決定來源是否可在該 tenant 顯示與啟用。
- 建議 gate 層級：
  - org contract（是否購買 Add-on）
  - company enable（是否啟用功能）
  - branch override（是否局部開關）

### 6.3 Demo / staging / production
- 建議 registry 資料與 `environment_type` 強綁：
  - demo 只能影響 demo
  - production 只能影響 production

## 7) Minimal Schema Proposal (No Migration in This Round)

### 7.1 New table proposal
- `attendance_source_registry`（新提案）

### 7.2 Existing table linkage（不變更、僅關聯提案）
- `attendance_logs`
- `line_webhook_event_logs`
- `line_bindings`
- `attendance_import_batches`（提案/既有規劃）
- `attendance_import_records_staging`（提案/既有規劃）

### 7.3 Optional extension（後續）
- `attendance_source_registry_history`（配置歷史版本與diff）
- `attendance_source_health_logs`（來源健康監控）

## 8) Phase Planning

### 8.1 Phase 1 必做
- 定義 `attendance_source_registry` canonical model（文件凍結）
- 支援三種 `source_type` 的統一枚舉：
  - `line`
  - `external_api`
  - `manual_upload`
- 明確 enable/disable 與 scope resolve 規則
- 與現有 audit/batch/review 資料模型建立關聯規範

### 8.2 Phase 1.1
- `config_json` 驗證規格（json schema）與版本策略
- branch override + fallback 的完整測試矩陣
- source registry 與 feature gate 的管理面欄位細化

### 8.3 之後再做
- Source health dashboard / SLA / retry orchestration
- 自動化 anomaly detection（來源異常偵測）
- Cross-tenant connector marketplace（多供應商模板）

## 9) Non-goals (This Round)
- 不做 migration
- 不做 route
- 不做 payroll/shift integration
