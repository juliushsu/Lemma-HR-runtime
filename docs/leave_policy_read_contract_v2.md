# Leave Policy Read Contract v2 (Staging)

## Goal
避免前端在假日來源與法遵提醒自行猜 country 邏輯；後端統一以 `policy country + allow_cross_country_holiday_merge` 決定預設資料範圍。

## Country Resolve Rule
1. 先以 `org_id + company_id` 找目前可用 policy profile（同環境）。
2. 若 request 帶 `country_code`，優先以該 country 過濾。
3. 若未帶 `country_code`：
   - `allow_cross_country_holiday_merge = false`：只回 policy `country_code`。
   - `allow_cross_country_holiday_merge = true`：允許跨國資料。

## Functions
- `list_holiday_calendar_sources(org_id, company_id)`
- `list_holiday_calendar_sources(org_id, company_id, country_code)`
- `list_holiday_calendar_days(org_id, company_id, from_date, to_date)`
- `list_holiday_calendar_days(org_id, company_id, country_code, from_date, to_date)`
- `list_leave_compliance_warnings(org_id, company_id)`
- `list_leave_compliance_warnings(org_id, company_id, country_code)`

## Notes
- v1 無 `country_code` 版本保留，作為 wrapper。
- v2 多 `country_code` 版本可直接給前端 settings/legal policy 頁使用。
