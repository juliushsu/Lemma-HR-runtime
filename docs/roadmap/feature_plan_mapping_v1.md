# Sprint 2B.11.3 - Feature Plan Mapping v1 Proposal

## Goal
- 明確定義 feature 與方案（plan）映射規則，供 UI / API / system pages 一致採用。
- 本文件為 proposal only，不含 migration / route / billing engine 實作。

## 1) Plan Tiers 與 Feature Keys 映射（v1）

### Base（主方案內含）
- `attendance.manual_upload.basic` = enabled
- `attendance.line_checkin` = enabled
- `attendance.manual_upload.advanced` = disabled
- `attendance.external_api.standard` = disabled
- `attendance.external_api.enterprise` = disabled

### Pro（主方案內含）
- `attendance.manual_upload.basic` = enabled
- `attendance.manual_upload.advanced` = enabled
- `attendance.line_checkin` = enabled
- `attendance.external_api.standard` = enabled
- `attendance.external_api.enterprise` = disabled

### Add-on（可疊加）
- `attendance.manual_upload.advanced`（可加購給 Base）
- `attendance.external_api.standard`（可加購給 Base）
- `attendance.external_api.enterprise`（可加購給 Pro 或 Enterprise 特約）

### Enterprise（主方案內含）
- `attendance.manual_upload.basic` = enabled
- `attendance.manual_upload.advanced` = enabled
- `attendance.line_checkin` = enabled
- `attendance.external_api.standard` = enabled
- `attendance.external_api.enterprise` = enabled

## 2) 主方案內含 vs Add-on 原則
- 主方案內含（included）：由 plan tier 預設決定，不需額外加購。
- Add-on：不在當前 plan tier 的 included 清單內，但可透過授權追加。
- 同一 feature 不可同時被定義為「該 tier included 且必須 add-on」；若衝突，以 backend mapping 為準。

## 3) source=plan / source=override / source=default 正式定義
- `source=plan`：由後端 plan mapping 規則直接解出（含 included 與已生效 add-on entitlement）。
- `source=override`：由 `organization_features`（或正式 override data source）明確覆蓋 plan 決策。
- `source=default`：plan 與 override 都無明確設定時，採系統預設值（通常為 disabled）。

## 4) enabled / disabled / locked 正式語意
- `enabled`：功能可用，API 入口可通過 feature gate。
- `disabled`：功能不可用，API 入口應回 `FEATURE_NOT_ENABLED`。
- `locked`：功能對當前角色或方案不可操作（可見但不可執行，應顯示升級或權限引導）；API 層仍以 `disabled` 決策強制拒絕。

## 5) Attendance Feature Keys（本期）
- `attendance.manual_upload.basic`
- `attendance.manual_upload.advanced`
- `attendance.line_checkin`
- `attendance.external_api.standard`
- `attendance.external_api.enterprise`

## 6) Resolver Single Source of Truth Rule
- `feature status 的單一來源應由 backend resolver 決定，前端只做展示與引導。`

## 7) 建議的最小決策順序（v1）
1. override（organization/company 明確覆蓋）
2. plan（tier + add-on entitlement）
3. default（系統預設）

## Non-goals（This Round）
- 不做 migration
- 不做 route
- 不做 billing engine
