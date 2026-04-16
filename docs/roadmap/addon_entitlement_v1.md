# Sprint 2B.15 - Add-on Entitlement Visibility v1 (Proposal)

## Goal
- 收斂 `main plan` 與 `add-on entitlement` 正式語意，讓 UI / API / system 使用同一套規則。
- 本文件為 proposal only，不含 migration / route / billing / payment 實作。

## 1) Main Plan vs Add-on 正式定義
- `main plan`：
  - 組織的主方案層級（`Base | Pro | Enterprise`）。
  - 決定 baseline entitlement（預設可用功能集合）。
- `add-on entitlement`：
  - 獨立於 main plan 的附加授權。
  - 只做「額外加值」，不改 main plan code 本身。
  - 由 `addons[]` 表示可見狀態（current-plan 視角）。

## 2) 哪些 feature 屬於 add-on（避免誤解為主方案內含）
- attendance domain（v1 建議）：
  - `attendance.manual_upload.advanced`
  - `attendance.external_api.standard`
  - `attendance.external_api.enterprise`
- 說明：
  - 上述三項可作為 add-on entitlement，是否同時在高階 main plan 內含，仍以 backend mapping 為準。
  - `attendance.line_checkin` 建議視為主方案能力（通常不是 add-on），避免前端誤導。

## 3) Add-on 如何掛到 current plan 顯示
- `GET /api/system/current-plan`（現行/未來）：
  - `plan_code`：主方案代碼
  - `plan_label`：主方案顯示名稱
  - `addons[]`：已啟用 add-on key 列表（獨立於 plan_code）
- UI 原則：
  - 主方案顯示 `plan_label`
  - add-on 區塊顯示 `addons[]`
  - 不可用 add-on 反推主方案變更

## 4) source=plan 與 add-on entitlement 關係
- `source=plan` 定義包含：
  - main plan baseline entitlement
  - 已生效的 add-on entitlement（同層視為 plan source 的一部分）
- `source=override` 仍高於 `source=plan`：
  - override 可臨時關閉/開啟 feature
  - 但不改變 current plan 的 `plan_code` 與 `addons[]` 身分語意

## 5) current-plan 是否要回 `entitled_by = plan | addon`
- 建議：要（Phase next）
- 理由：
  - 前端可明確標記「此功能由主方案提供」或「由 add-on 提供」。
  - 避免把 add-on 誤判成主方案內含。
- 建議 shape（未實作）：
  - `feature_entitlements[]`:
    - `feature_key`
    - `enabled`
    - `entitled_by`: `plan | addon | none`

## 6) Plan / Add-on 正式邊界（一句話）
- 主方案定義 baseline，add-on 只做增量授權；兩者都屬 entitlement source，但語意不可混用。

## Non-goals
- 不做 migration
- 不做 route
- 不做 billing / payment
