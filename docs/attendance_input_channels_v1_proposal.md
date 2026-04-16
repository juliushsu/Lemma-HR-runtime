# Attendance Input Channels v1 Proposal

## 1) Input Channels Scope (v1)

### A. LINE 打卡
- User path:
  - 員工透過 LINE（LIFF / 官方帳號）提交上下班打卡。
  - 系統寫入 canonical `attendance_logs`，標記 `source_type='line_liff'`。
- Expected fields:
  - `employee_id`
  - `checked_at`
  - `check_type` (`check_in` / `check_out`)
  - optional GPS (`gps_lat`, `gps_lng`)
  - optional `source_ref`（LINE message id / event id）

### B. 外部 API 匯入
- User path:
  - 由第三方系統（考勤機、既有 HRIS）透過 API 批次送入打卡資料。
  - 先落地到 import staging，再進入 canonical `attendance_logs`。
- Expected fields:
  - 來源系統員工識別（需對應本系統 `employee_id`）
  - 打卡時間、類型、來源 metadata
  - 批次識別碼（batch id）

### C. 打卡單上傳 + 人工校正
- User path:
  - 上傳 CSV / Excel / PDF（先以 CSV/Excel 為主）。
  - 系統解析為 staging records，提供人工校正後再寫入 canonical logs。
- Expected fields:
  - 員工代碼 / 姓名
  - 日期時間
  - 上下班類型
  - optional 分店、備註

## 2) Canonical Data Model Proposal

### Existing canonical table (keep as core write target)
- `attendance_logs`
  - 持續作為最終權威資料（single source of truth）
  - 主要欄位：
    - scope: `org_id`, `company_id`, `branch_id`, `environment_type`, `is_demo`
    - employee/time: `employee_id`, `attendance_date`, `checked_at`, `check_type`
    - source: `source_type`, `source_ref`
    - geo: `gps_lat`, `gps_lng`, `geo_distance_m`, `is_within_geo_range`
    - state: `status_code`, `is_valid`, `is_adjusted`, `note`

### Proposed supporting tables (minimal extension proposal)
- `attendance_import_batches`
  - 目的：追蹤外部 API / 上傳檔案批次生命周期
  - suggested fields:
    - `id`, `org_id`, `company_id`, `environment_type`
    - `import_channel` (`external_api` / `upload`)
    - `source_system`
    - `file_name` (nullable)
    - `status` (`received` / `parsed` / `validated` / `partially_applied` / `applied` / `failed`)
    - `total_records`, `accepted_records`, `rejected_records`
    - `started_at`, `completed_at`
    - `created_by`, `updated_by`

- `attendance_import_records_staging`
  - 目的：保存匯入前/校正中紀錄，不直接污染 canonical logs
  - suggested fields:
    - `id`, `batch_id`, `org_id`, `company_id`, `environment_type`
    - raw payload: `raw_employee_ref`, `raw_checked_at`, `raw_check_type`, `raw_branch_ref`, `raw_payload`
    - normalized: `employee_id`, `branch_id`, `checked_at`, `check_type`
    - validation: `validation_status`, `validation_errors`
    - review: `review_status`, `review_note`, `reviewed_by`, `reviewed_at`
    - apply: `applied_log_id` (nullable), `applied_at`

## 3) source_type / import_batch / review flow Proposal

### source_type v1 normalization
- `line_liff`: LINE 前台打卡
- `import`: 已通過外部 API / 上傳流程後，寫入 canonical logs 的來源類型
- `manual`: 人工新增或人工校正落地
- Existing values (`web`, `mobile`, `kiosk`, `line_liff`, `manual`, `import`) 可維持

### import_batch flow
1. Receive batch
2. Parse and normalize into staging
3. Validate employee/branch/time/check_type
4. Human review for invalid/conflict records
5. Apply accepted records to `attendance_logs`
6. Record batch outcome and audit trail

### review flow
- 自動判定：
  - 可自動匹配且無衝突 -> `auto_approved`
  - 有缺值/衝突 -> `needs_review`
- 人工判定：
  - `approved` -> 寫入 canonical log
  - `rejected` -> 保留 staging 記錄，不寫入 canonical
  - `corrected_and_approved` -> 人工修正後寫入 canonical

## 4) Permission Recommendations

### Role mapping (suggested)
- `viewer`
  - read logs / summary / import batch status
- `operator`
  - create import batch（upload/API trigger）
  - perform record review/approve within scope
- `manager`
  - approve/reject records in owned branch/company scope
  - review override actions
- `admin` / `super_admin`
  - full import config + apply + rollback orchestration

### Scope enforcement
- 全程沿用現有 scope：`org/company/branch/environment_type`
- 批次與 staging record 需綁同一 scope，不可跨 scope 套用

## 5) Add-on Packaging Proposal (Paid Modules)

### Core (base)
- 既有出勤 logs / summary 查詢
- branch/GPS/boundary 解析顯示

### Add-on A: LINE Clock-in
- LINE 打卡入口
- LINE event 驗證與防重入
- 基礎打卡成功/失敗回饋

### Add-on B: Timesheet Upload + Review
- CSV/Excel upload
- staging validation
- review UI/API workflow

### Add-on C: External Attendance API Connector
- inbound API + batch lifecycle
- mapping templates（employee/branch code mapping）
- retries/monitoring

### Add-on D: Compliance & Audit Pack (optional)
- advanced audit logs
- exception reports
- approval SLA tracking

## 6) Relation with Branch / GPS / Attendance Boundary

### Required linkage rules
- 每筆 canonical `attendance_logs` 必須可追溯 `branch_id`（允許早期歷史資料為 null，但新資料應盡量對齊）
- boundary resolve order:
  1. company default
  2. branch override
- runtime output should expose:
  - `branch_id`
  - `branch_name` / `location_name`
  - `resolved_from`
  - `resolved_checkin_radius_m`
  - `resolved_is_attendance_enabled`

### Channel-specific behavior
- LINE 打卡
  - 優先使用 employee default branch
  - 若有 GPS，計算 `geo_distance_m` + `is_within_geo_range`
- 外部 API 匯入
  - 若 payload 含 branch ref，先 mapping；無則 fallback employee default branch
- 上傳 + 人工校正
  - 人工可修正 branch 映射，核准後再寫 canonical

## Product Sequencing Recommendation (Aligned)

1. 先修 `branch_name` 顯示（已是前置基礎）
2. 完成本提案（本文件）
3. 依優先順序落地：
   - 第一優先：LINE 打卡
   - 第二優先：打卡單上傳
   - 第三優先：外部 API 匯入

Reasoning:
- LINE：既有經驗多、導入速度最快
- 上傳：符合台灣企業常見需求
- 外部 API：整合成本最高，待 canonical 更穩定再推進

