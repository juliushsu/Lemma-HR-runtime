# Attendance LINE Multilingual Worker UI v1 Proposal

## 1) 員工端 LINE 多語策略

- 目標：同一套 LINE 打卡流程，依員工語言偏好提供一致訊息，不改核心業務規則。
- 原則：
  - 文案與業務邏輯分離（message key + params）。
  - 所有可見文字均由 locale dictionary 驅動。
  - 錯誤碼固定，語系僅影響顯示訊息。
- 範圍（Worker UI）：
  - 打卡成功回覆
  - 打卡失敗回覆
  - 綁定流程提示
  - 常見指引訊息（例如請先綁定）

## 2) locale 偵測優先順序

1. webhook payload 明確帶入 `locale`（若可信且有支援）
2. `line_bindings.locale_preference`（綁定層）
3. `employees.preferred_locale`（員工層）
4. `users.locale_preference`（使用者層）
5. `company_settings.default_locale`
6. 系統預設：`en`

備註：
- Phase 1 先使用上述固定優先序，不做動態權重/學習。

## 3) 初期支援語言清單

- `zh-TW`（繁體中文）
- `en`（英文）
- `ja`（日文）

Phase 1 建議先不開：
- `ko`
- `zh-CN`
- `th`

## 4) canonical message key proposal

命名規格：
- `attendance.line.<domain>.<event>`

建議 key（Phase 1 核心）：
- `attendance.line.bind.success`
- `attendance.line.bind.not_found`
- `attendance.line.bind.token_expired`
- `attendance.line.checkin.success`
- `attendance.line.checkout.success`
- `attendance.line.error.identity_not_bound`
- `attendance.line.error.attendance_disabled`
- `attendance.line.error.out_of_boundary`
- `attendance.line.error.duplicate_check`
- `attendance.line.error.invalid_request`
- `attendance.line.error.internal`

建議參數（template params）：
- `{employee_display_name}`
- `{check_type_label}`
- `{checked_at_local}`
- `{branch_name}`
- `{distance_m}`
- `{radius_m}`
- `{request_id}`

## 5) employee / line binding 的語言欄位建議

## 5.1 employee 端（既有可用）
- `employees.preferred_locale`：作為員工層偏好語系來源。

## 5.2 line binding 端（建議新增）
- `line_bindings.locale_preference`（nullable）
  - 綁定成功時可初始化為 employee/user locale。
  - 允許後續由 LINE 指令切換（Phase 2）。

## 5.3 optional metadata
- `line_bindings.last_detected_locale`
- `line_bindings.locale_source`（`payload|binding|employee|user|company|default`）

## 6) fallback 規則

- locale fallback chain：
  1. requested locale（若有）  
  2. 同語系基底（例如 `ja-JP` -> `ja`）  
  3. `en`  
  4. 最終硬編碼安全字串（避免空白訊息）

- key fallback chain：
  1. 精確 key + locale
  2. 同 key + `en`
  3. `attendance.line.error.internal`（通用）

- params fallback：
  - 缺參數時，改用中性語句，不顯示 `undefined/null`。

## 7) 哪些訊息 Phase 1 必翻

綁定相關（必翻）：
- 綁定成功
- 綁定 token 無效/過期
- 尚未綁定提示

打卡成功（必翻）：
- 上班打卡成功
- 下班打卡成功

打卡失敗（必翻）：
- 未綁定身份
- 分店/公司停用打卡
- 超出打卡邊界
- 重複打卡
- 請求格式錯誤
- 系統忙碌（通用 internal error）

不在 Phase 1（可先不翻）：
- 長篇教學文案
- 管理端稽核說明
- 進階排班/法規提醒訊息

