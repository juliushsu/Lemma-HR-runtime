legal-governance-consumption-map.v1.md
# Legal Governance Consumption Map v1

## 1. 目的（Purpose）

本文件定義：

- 法務治理層（Legal Governance Layer）
如何被各業務模組（Payroll / Leave / Contract）消費（consume）
- 各模組應如何顯示、使用與回應 governance checks
- 統一治理語言（shared schema）與 UI 行為

本文件為 Phase 1（read-first architecture）之核心設計。

---

## 2. 核心設計原則

### 2.1 分層責任

| 層級 | 職責 |
|------|------|
| Legal Governance Layer | 法規比對、風險判斷、AI建議 |
| HR Modules | 實際執行（薪資、假勤、合約） |

👉 法務+ 不直接修改資料  
👉 各模組不自行解釋法規

---

### 2.2 單一治理來源（Single Source of Truth）

所有法遵差異、風險與建議，統一來自：
GET /api/legal/governance-checks
---

### 2.3 不自動覆寫（Non-Autonomous Enforcement）

- AI 不可直接修改公司政策
- 僅提供：
  - 差異
  - 風險
  - 建議

公司必須：
- 採納（adopt）
- 保留現狀（keep_current）
- 接受風險（acknowledge_risk）

---

## 3. Governance Check Schema（共用語言）

所有模組必須共用以下欄位語意：

### 核心欄位

- `domain`
- `impact_domain`
- `rule_strength`
- `severity`
- `company_decision_status`
- `title`
- `reason_summary`

### 三段式比較（核心）

- `statutory_minimum.summary`
- `company_current_value.summary`
- `ai_suggested_value.summary`

### 法源

- `source_ref.label`
- `source_ref.effective_from`

---

## 4. Rule Semantics（治理語意）

### 4.1 rule_strength

| 值 | 說明 |
|----|------|
| mandatory_minimum | 法定最低，不可低於 |
| recommended_best_practice | 建議最佳實務 |
| company_discretion | 公司可自行決定 |

---

### 4.2 severity

| 值 | 說明 |
|----|------|
| critical | 高違法風險 |
| high | 明顯風險 |
| medium | 潛在風險 |
| low | 輕微差異 |
| info | 資訊提示 |

---

### 4.3 company_decision_status

| 值 | 說明 |
|----|------|
| pending_review | 尚未處理 |
| adopted | 已採納 |
| kept_current | 維持現狀 |
| acknowledged_risk | 已知風險 |

---

## 5. 模組消費設計（Consumption Design）

---

# 5.1 Payroll 模組

## 使用範圍
impact_domain = payroll
## 顯示位置

- Payroll Settings 頁
- Payroll Preview 頁
- Payroll Run 前檢核

## 顯示內容

- 高風險政策警告
- 成本影響提示
- AI建議薪資處理方式

## UI 行為

- 顯示 warning panel
- 不阻擋計算
- 可導向法務+ detail

---

# 5.2 Leave / Attendance 模組

## 使用範圍
impact_domain = leave | attendance
## 顯示位置

- 出勤制度設定頁
- 假勤制度頁
- 請假 / 補登流程

## 顯示內容

- 法定 vs 公司制度差異
- 假別是否合法
- 出勤規則風險

## UI 行為

- 顯示治理提示
- 不自動修改制度
- 在流程中提示（contextual warning）

---

# 5.3 Contract 模組

## 使用範圍
impact_domain = contract
## 顯示位置

- 合約 detail 頁
- 合約審核流程
- 合約編輯頁

## 顯示內容

- 條款風險
- 與公司制度衝突
- 與法規差異

## UI 行為

- 條款旁顯示 warning
- 提供 AI 建議摘要
- 可跳至 governance detail

---

## 6. UI 層分工

### 6.1 法務+（/legal）

- 全局視角
- 顯示全部 governance checks
- 支援 filter
- 提供 detail drawer

---

### 6.2 模組頁（Payroll / Leave / Contract）

- 任務視角
- 只顯示相關 checks
- 嵌入提示，不干擾主流程

---

## 7. Data Flow
Legal Knowledge / AI / 法規來源 ↓ Legal Governance Checks（DB / API） ↓ ┌──────────────┬──────────────┬──────────────┐ ↓              ↓              ↓ Payroll        Leave          Contract ↓              ↓              ↓ UI提示         UI提示         UI提示
---

## 8. Phase 邊界

### Phase 1（本文件）

- Read-only governance checks
- UI consumption
- 不做 mutation

---

### Phase 2

- acknowledge_warning
- keep_current
- adopt_suggestion

---

### Phase 3

- 模組內直接採納建議
- 合約條款建議替換
- 薪資規則自動校正建議

---

## 9. 不允許事項

- ❌ 自動修改公司制度
- ❌ 客戶切換法律模型
- ❌ 即時 uncontrolled 法規抓取
- ❌ 未經確認自動套用 AI 建議

---

## 10. 核心產品定位

Legal Governance Layer 的定位：

> 將「法規 → 差異 → 風險 → 建議」轉化為可操作的治理資訊，
> 並注入到薪資、假勤與合約決策流程中。

---

## 11. 未來擴展

- Insurance recommendation（高風險工作）
- 多國法規切換
- 法規版本追蹤
- clause-level 合約分析
- AI-driven compliance scoring
