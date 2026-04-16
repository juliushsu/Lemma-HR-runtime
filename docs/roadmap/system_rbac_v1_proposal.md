# Sprint 2B.9.1 - System RBAC Proposal / Contract Alignment

## Goal
- 定義 system layer 的角色權限邊界，作為前後端共用 contract。
- 本文件為 proposal only，不含 migration / route 實作。

## 1) System Layer 可見角色

### `owner`
- 可見且可操作全部 system pages。
- 擁有 system layer 最高權限。

### `super_admin`
- 可見 system layer，但採「受限可見」。
- 不能執行高風險的全域治理操作（例如 owner 管理、關鍵計費策略變更、全域 API key rotate）。

### 其他角色（`admin` / `manager` / `operator` / `viewer`）
- 完全不可見 system layer。
- 若直接打 system endpoints，回 `403 FORBIDDEN`。

## 2) System Pages 最小 Permission Matrix

| Page | owner | super_admin |
|---|---|---|
| `admin-users` | full (`read/write`) | limited (`read`, `invite/update non-owner`) |
| `roles` | full (`read/write`) | limited (`read`, `assign within non-owner scope`) |
| `features` | full (`read/write`) | limited (`read`, `toggle non-critical flags`) |
| `api-keys` | full (`read/write/rotate/revoke`) | limited (`read`, `create scoped key`, `revoke scoped key`) |
| `billing` | full (`read/write`) | read-only (`read`) |

補充規則：
- `super_admin` 不可提升任何人為 `owner`。
- `super_admin` 不可修改 `owner` 帳號與 owner-only 權限。
- 所有 system write 操作必須保留 audit（actor / before / after / reason / timestamp）。

## 3) System Layer 與 Organization Layer 界線

### System Layer（platform governance）
- 管理全域治理能力，不直接承載日常業務資料。
- 典型範圍：
  - `admin-users`
  - `roles`
  - `features`
  - `api-keys`
  - `billing`

### Organization Layer（tenant business operations）
- 管理 org/company/branch 的業務資料與流程。
- 典型範圍：
  - HR（employees/departments/attendance）
  - LC（documents/cases）
  - Settings（company profile/locations/attendance boundary）

### 邊界原則（contract）
1. System layer 不直接修改業務主檔（如 employee/legal document）。
2. Organization layer 不提供 platform governance 管理能力（如 billing/api-keys）。
3. 任何跨層操作需透過明確 adapter + audit，不可隱式 side-effect。

## 4) Frontend/Backend Contract 建議

### Visibility gate（前端）
- `/api/me` 應回傳：
  - `data.system_access.visible`（boolean）
  - `data.system_access.permission_level`（`owner` | `super_admin_limited` | `none`）
- Sidebar 根據 `system_access.visible` 決定是否顯示 System 區塊。

### Authorization gate（後端）
- System routes 先做角色 gate：
  - owner: allow
  - super_admin: allow with action-level restrictions
  - others: deny 403
- API envelope 維持 canonical：`{ schema_version, data, meta, error }`

## 5) Phase Cut

### Phase 1（本輪凍結）
- 角色可見性決策：`owner full`, `super_admin limited`, others hidden
- 五個 system pages 最小 permission matrix
- system/org layer contract 邊界

### Phase 1.1
- action-level permission code map（逐 endpoint）
- UI route guard + empty/forbidden states 標準化

### Later
- 細粒度 policy engine（ABAC / condition-based）
- delegated administration（可授權但不可升權）
