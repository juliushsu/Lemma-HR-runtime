# Sprint 2B.x - Attendance Manual Upload v1 Proposal

## Goal
- 定義 `manual_upload` 出勤來源的最小可用規格（proposal only）。
- 本文件僅含模型與流程提案，不含 migration / route 實作。

## 1) Canonical Model Relation

### 1.1 Core write target
- 最終權威資料仍為 `attendance_logs`。
- 上傳資料先進 staging，經 validation/review 後再寫 canonical。

### 1.2 Suggested relation chain
1. `attendance_source_registry`（來源開關與設定）
2. `attendance_import_batches`（一次上傳對應一個 batch）
3. `attendance_import_records_staging`（逐列資料、驗證結果、覆核狀態）
4. `attendance_logs`（核准落地）
5. audit log（上傳、解析、覆核、套用全流程）

## 2) Source Type
- `source_type`: `manual_upload`
- 建議 canonical 寫入時：
  - 可先使用 `attendance_logs.source_type='manual'`（人工校正後）
  - 若由批次自動套用可標記 `import`，並帶 `source_channel='manual_upload'`

## 3) Config / Batch / Review Flow

### 3.1 Config shape proposal
```json
{
  "allowed_file_types": ["csv", "xlsx"],
  "max_rows_per_file": 10000,
  "template_version": "v1",
  "required_columns": ["employee_ref", "checked_at", "check_type"],
  "allow_partial_apply": true,
  "require_reviewer": true,
  "auto_approve_when_no_error": false
}
```

### 3.2 Batch lifecycle proposal
1. `uploaded`
2. `parsed`
3. `validated`
4. `needs_review` / `ready_to_apply`
5. `applied` / `failed`

### 3.3 Review flow proposal
- validation gates:
  - 必填欄位完整
  - check_type 合法（check_in/check_out）
  - 員工/分店可對應
  - 時間格式與時區可解析
- reviewer actions:
  - `approved`
  - `rejected`
  - `corrected_and_approved`
- apply rule:
  - 僅 `approved` / `corrected_and_approved` 寫入 `attendance_logs`

## 4) Org / Company / Branch / Feature Gating Relation

### 4.1 Scope binding
- 每個 upload batch 強綁：
  - `org_id`
  - `company_id`
  - `environment_type`
  - `branch_id`（可空，後續可人工修正映射）
- 禁止跨公司/跨環境混批。

### 4.2 Feature gating
- `feature_gate_key`: `attendance.manual_upload.enabled`
- 建議 gating 層級：
  - org 訂閱層
  - company 啟用層
  - branch override（例如特定分店禁用）

## 5) Phase Plan

### Phase 1
- 凍結 manual upload canonical contract
- 單檔 upload -> staging -> review -> apply 最小流程
- 可回溯 batch 與逐筆覆核決策

### Phase 1.1
- 模板版本管理與欄位映射 UI 規範
- 部分套用（partial apply）策略細化
- 錯誤分類與覆核 SLA 指標

### Later
- PDF/OCR 擴充（若產品決策需要）
- 智能欄位自動對應
- 大量檔案分片與併發處理優化

## Non-goals (This Round)
- 不做 migration
- 不做 route
- 不碰 payroll / shift
