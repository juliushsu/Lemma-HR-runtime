# Sprint 2B.x - Attendance External API v1 Proposal

## Goal
- 定義 `external_api` 出勤來源的最小可用規格（proposal only）。
- 本文件僅含模型與流程提案，不含 migration / route 實作。

## 1) Canonical Model Relation

### 1.1 Core write target
- 最終權威資料仍為 `attendance_logs`。
- external API 匯入資料經過 validation/review 後才寫入 canonical log。

### 1.2 Suggested relation chain
1. `attendance_source_registry`（source 開關與配置）
2. `attendance_import_batches`（批次生命週期）
3. `attendance_import_records_staging`（單筆暫存/驗證/覆核）
4. `attendance_logs`（核准後落地）
5. audit log（記錄 ingest/validate/review/apply 決策）

## 2) Source Type
- `source_type`: `external_api`
- 建議 canonical 寫入時：
  - 可先沿用 `attendance_logs.source_type='import'`
  - 透過 `source_channel='external_api'`（metadata）保留來源辨識
  - 或未來 schema 擴充後改為獨立 `external_api`

## 3) Config / Batch / Review Flow

### 3.1 Config shape proposal
```json
{
  "provider_name": "string",
  "auth_mode": "hmac|bearer|ip_allowlist",
  "ip_allowlist": ["203.0.113.0/24"],
  "max_batch_size": 5000,
  "idempotency_key_field": "event_id",
  "employee_mapping_mode": "employee_code|email|external_ref",
  "default_branch_resolution": "employee_default_branch"
}
```

### 3.2 Batch lifecycle proposal
1. `received`
2. `parsed`
3. `validated`
4. `needs_review` / `partially_applied`
5. `applied` / `failed`

### 3.3 Review flow proposal
- auto-approved:
  - 員工可對應、check_type/time 合法、無重複衝突
- needs_review:
  - 員工對應失敗
  - branch 無法解析
  - 重複事件或時間衝突
- reviewer action:
  - `approved`
  - `rejected`
  - `corrected_and_approved`

## 4) Org / Company / Branch / Feature Gating Relation

### 4.1 Scope binding
- 批次與紀錄必須綁定：
  - `org_id`
  - `company_id`
  - `environment_type`
  - `branch_id`（可空，核准時 resolve）
- 禁止跨 scope 批次套用。

### 4.2 Feature gating
- `feature_gate_key`: `attendance.external_api.enabled`
- 建議 gating 層級：
  - org 合約層（是否購買）
  - company 開關
  - branch override（局部停用）

## 5) Phase Plan

### Phase 1
- 凍結 external API canonical contract
- 批次 ingest + staging validation +人工覆核最小流程
- 落地 `attendance_logs` 並保留 audit trace

### Phase 1.1
- mapping template 管理（multi-provider）
- 更完整 idempotency / retry policy
- 批次品質報表（accepted/rejected/error ratio）

### Later
- 雙向同步（outbound ack）
- provider marketplace connectors
- 進階異常偵測（來源品質分數）

## Non-goals (This Round)
- 不做 migration
- 不做 route
- 不碰 payroll / shift
