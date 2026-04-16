# Sprint 2B.10 - Feature Gating v1 Proposal + Minimal Schema Proposal

## Goal
- 定義 Lemma 平台功能分級與啟用規則，作為前後端一致採用的 contract。
- 本文件為 proposal only，不含 migration / route 實作。

## 1) Plan Tiers（v1）
- `Base`: 核心功能，預設方案。
- `Pro`: 進階功能集合，含較高操作上限。
- `Add-on`: 可獨立加購的功能包（可疊加在 Base/Pro）。
- `Enterprise`: 企業級功能與更高治理能力（可含專屬條件）。

## 2) Feature Keys Proposal（v1）

### Mandatory keys（本輪先定）
- `attendance.manual_upload.basic`
- `attendance.manual_upload.advanced`
- `attendance.line_checkin`
- `attendance.external_api.standard`
- `attendance.external_api.enterprise`

### Optional extension keys（後續）
- `attendance.line_checkin.multilingual.phase11`
- `attendance.external_api.dedicated_connector`
- `attendance.external_api.sla_enterprise`

## 3) Org / Company 層級啟用模型

### 3.1 Scope model
- `org` 層：合約與主授權來源（entitlement source of truth）。
- `company` 層：啟用/停用與細節覆蓋（在 org entitlement 允許範圍內）。

### 3.2 Resolve order（v1）
1. `org entitlement`（是否有權使用該 feature）
2. `company override`（enabled/disabled，若未設定則沿用 org default）
3. `runtime guard`（必要前置條件，例如 source registry enabled）

### 3.3 Decision
- 若 org 無 entitlement：`deny`
- 若 org 有 entitlement 且 company 明確停用：`deny`
- 若 org 有 entitlement 且 company 未停用：`allow`

## 4) Source-type 與 Feature 關聯

### 4.1 Attendance source mapping（v1）
- `manual_upload` source 依賴：
  - `attendance.manual_upload.basic`（MVP）
  - `attendance.manual_upload.advanced`（進階能力）
- `line` source 依賴：
  - `attendance.line_checkin`
- `external_api` source 依賴：
  - `attendance.external_api.standard`（標準版）
  - `attendance.external_api.enterprise`（企業版擴充）

### 4.2 Compatibility principle
- source registration 成功不等於可執行；執行時仍須通過 feature gate。
- feature gate 與 source enable 必須同時為 true 才可使用。

## 5) UI / API / Route Feature Access 判斷規則

### 5.1 UI（frontend）
- 以 `/api/me`（或等效 capability endpoint）取得 feature access snapshot。
- Sidebar / page entry 規則：
  - `allow`: 顯示正常入口
  - `deny`: 隱藏入口或顯示 upgrade CTA（依產品策略）
- UI 不可當作唯一安全邊界；僅做引導。

### 5.2 API / Route（backend）
- 每個受管 endpoint 在 handler 開頭檢查 feature access。
- 建議統一 guard helper（proposal）：
  - `require_feature_access(ctx, scope, feature_key)`
- 未通過時回 `403 FEATURE_FORBIDDEN`（保持 canonical envelope）。

### 5.3 Canonical response（不變）
- 維持：
  - `schema_version`
  - `data`
  - `meta`
  - `error`

## 6) Minimal Schema Proposal（No Migration This Round）

### 6.1 `feature_catalog`（平台功能目錄）
- `feature_key` (unique)
- `display_name`
- `module`
- `tier_hint` (`Base|Pro|Add-on|Enterprise`)
- `status` (`active|deprecated`)

### 6.2 `plan_tier_feature_rules`（方案預設規則）
- `plan_tier`
- `feature_key`
- `default_enabled`
- `limit_json`（可選）

### 6.3 `org_feature_entitlements`（org 授權）
- `org_id`
- `feature_key`
- `is_entitled`
- `source`（contract/manual/grant）
- `effective_from`, `effective_to`

### 6.4 `company_feature_overrides`（company 覆蓋）
- `org_id`
- `company_id`
- `feature_key`
- `is_enabled`
- `reason`

### 6.5 `feature_access_audit_logs`（稽核）
- `org_id`, `company_id`
- `feature_key`
- `decision` (`allow|deny`)
- `actor_user_id`（若有）
- `reason_code`
- `context_json`
- `created_at`

## 7) Audit 建議（v1）
- 所有 feature gate 寫操作（entitlement/override 變更）必留 audit：
  - actor
  - before/after
  - reason
  - timestamp
- 高風險功能（例如 external_api enterprise）建議雙重審批（後續）。

## 8) Phase 切分

### Phase 1 必做
- 凍結 feature keys（含本輪 mandatory 5 keys）
- 凍結 org/company resolve 規則
- backend route guard contract（deny code + envelope）
- UI capability 判斷 contract（可見/不可見/CTA）
- 最小 audit 欄位定義

### 之後再做
- usage/limit enforcement（配額與節流）
- billing engine 深度整合（本輪不做）
- 更細粒度 ABAC/conditional policy
- 自動化升降級流程與通知

## Non-goals（This Round）
- 不做 migration
- 不做 route
- 不碰 payroll
- 不碰 shift
- 不直接做 billing engine
