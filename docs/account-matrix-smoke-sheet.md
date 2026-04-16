# Account Matrix Smoke Sheet

## 1) `juliushus@gmail.com`
- 預期 role: `owner`
- 預期 scope: `org`（production）
- 預期 `/api/me` 重點欄位:
  - `schema_version = auth.me.v1`
  - `data.user.email = juliushus@gmail.com`
  - `data.memberships[0].role = owner`
  - `data.memberships[0].scope_type = org`
  - `data.environment_type = production`
  - `data.current_org.id = 10000000-0000-0000-0000-000000000001`
  - `data.current_company.id = 20000000-0000-0000-0000-000000000001`
- 預期可見模組: `Auth`, `HR+`, `LC+`（production scope）

## 2) `staging.superadmin@lemma.local`
- 預期 role: `super_admin`
- 預期 scope: `org`（production）
- 預期 `/api/me` 重點欄位:
  - `schema_version = auth.me.v1`
  - `data.user.email = staging.superadmin@lemma.local`
  - `data.memberships[0].role = super_admin`
  - `data.memberships[0].scope_type = org`
  - `data.environment_type = production`
  - `data.current_org.id = 10000000-0000-0000-0000-000000000001`
  - `data.current_company.id = 20000000-0000-0000-0000-000000000001`
- 預期可見模組: `Auth`, `HR+`, `LC+`（production scope）

## 3) `demo.admin@lemma.local`
- 預期 role: `admin`
- 預期 scope: `company`（demo only）
- 預期 `/api/me` 重點欄位:
  - `schema_version = auth.me.v1`
  - `data.user.email = demo.admin@lemma.local`
  - `data.memberships[0].role = admin`
  - `data.memberships[0].scope_type = company`
  - `data.environment_type = demo`
  - `data.current_org.id = 10000000-0000-0000-0000-000000000002`
  - `data.current_company.id = 20000000-0000-0000-0000-000000000002`
- 預期可見模組: `Auth`, `HR+`, `LC+`（demo scope；不可看到 production）

## 4) `staging.viewer@lemma.local`
- 預期 role: `viewer`
- 預期 scope: `company`（production）
- 預期 `/api/me` 重點欄位:
  - `schema_version = auth.me.v1`
  - `data.user.email = staging.viewer@lemma.local`
  - `data.memberships[0].role = viewer`
  - `data.memberships[0].scope_type = company`
  - `data.environment_type = production`
  - `data.current_org.id = 10000000-0000-0000-0000-000000000001`
  - `data.current_company.id = 20000000-0000-0000-0000-000000000001`
- 預期可見模組: `Auth`, `HR+`, `LC+`（read-oriented scope）

