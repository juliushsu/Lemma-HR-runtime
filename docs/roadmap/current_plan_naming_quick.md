# Current Plan Naming (Quick)

- canonical plan codes:
  - `Base`
  - `Pro`
  - `Enterprise`

- display labels:
  - `Base` -> `Base`
  - `Pro` -> `Pro`
  - `Enterprise` -> `Enterprise`

- add-on 是否獨立於 main plan:
  - 是，`addons[]` 獨立於 main plan。
  - main plan 由 `plan_code` 表示，add-on 由 `addons[]` 疊加。

- frontend 應以哪個欄位顯示:
  - 主方案名稱：優先顯示 `plan_label`（不要自行拼字）。
  - 若需邏輯判斷：使用 `plan_code`。
  - add-on 顯示：使用 `addons[]`。
