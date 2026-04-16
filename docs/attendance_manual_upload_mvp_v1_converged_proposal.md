# Sprint 2B.6.1 - 打卡單上傳 MVP 收斂版 Proposal（No Implementation）

## Goal
- 將 manual upload 從概念提案收斂為可施工的 Phase 1 規格。
- 本文件僅為 proposal，不含 migration / route / UI 實作。

## Phase 1 Scope（Frozen）

### 檔案格式
- 僅支援：
  - `CSV`
  - `XLSX`

### 明確不做
- `OCR`（Phase 1 不納入）

## 1) 最小流程（Phase 1）

1. `upload batch`
- 使用者上傳 CSV/XLSX，建立 `import_batch`（proposal）。

2. `parse`
- 系統解析檔案列資料到 staging records。
- 只做最小欄位驗證與格式正規化。

3. `preview`
- 回傳可預覽列表：
  - 可匯入
  - 需人工處理
  - 明確錯誤原因

4. `human review`
- 操作者針對錯誤列做人工修正或拒絕。

5. `confirm import`
- 只將通過列寫入 canonical。

## 2) Canonical Write Target（Phase 1）

### 2.1 `attendance_logs`（主要落地）
- 所有核准列寫入 `attendance_logs`。
- `source_type` 固定為 `manual_upload`（Phase 1 約定）。

### 2.2 `attendance_adjustments`（有人工修正時）
- 當 reviewer 對 parsed 值做更正後再核准：
  - 建議同步寫入 adjustment/audit 記錄（proposal）。

### 2.3 Proposal supporting entities
- `import_batches`（批次主檔）
- `import_review_tasks`（人工覆核任務）

## 3) 最低必要欄位 Mapping（Phase 1）

### 必要欄位
- `employee_code`
- `attendance_date`
- `check_type`
- `checked_at`
- `source_type = manual_upload`

### Mapping 規則（最小）
- `employee_code` -> `employees.employee_code`
- `attendance_date` -> canonical date（若缺，可由 `checked_at` 推導）
- `check_type` -> `check_in` / `check_out`
- `checked_at` -> ISO datetime（含時區或可解析為租戶預設時區）

## 4) 失敗情境（Phase 1 必含）

1. `employee not found`
- 無法以 `employee_code` 對應員工。
- 行為：標記該列為 `needs_review`。

2. `invalid datetime`
- `checked_at` 不可解析或不合法。
- 行為：標記錯誤，不可直接匯入。

3. `duplicate row`
- 同批內重複、或與既有 log 形成明顯重複（同 employee/check_type/checked_at）。
- 行為：標記 `duplicate`，需人工判定。

4. `branch unresolved`
- 無法由 employee default branch 或資料列資訊解析分店。
- 行為：標記 `needs_review`，人工指定 branch 後才可匯入。

## 5) Phase 1 規格摘要（可施工版本）

- 輸入：CSV/XLSX
- 流程：upload -> parse -> preview -> human review -> confirm import
- 最小 mapping：`employee_code / attendance_date / check_type / checked_at`
- canonical 寫入：
  - `attendance_logs`（必做）
  - `attendance_adjustments`（有人工更正時記錄）
- `source_type`：`manual_upload`
- 錯誤類型：employee not found / invalid datetime / duplicate row / branch unresolved

## 6) 延到 2B.6.2

- 更完整欄位映射模板（自訂欄位名、別名）
- partial import 策略細化（批次內分段提交與回滾策略）
- reviewer 工作佇列與 SLA 指標
- 較完整衝突偵測（跨日班、彈性工時特例）

## 7) 本階段不做

- OCR（包含影像/PDF 解析）
- 智慧辨識/AI 自動糾錯
- 薪資與排班引擎整合
- 外部 API 匯入（另案）
