# Endpoint Cheat Sheet (Frontend)

## `GET https://lemma-backend-staging-staging.up.railway.app/api/me`
- method: `GET`
- auth: `Bearer JWT` required
- query params: none
- response key: `data.user`, `data.memberships`, `data.current_org`, `data.current_company`, `data.locale`, `data.environment_type`

## `GET https://lemma-backend-staging-staging.up.railway.app/api/hr/employees`
- method: `GET`
- auth: `Bearer JWT` required
- query params: `org_id`, `company_id`, `branch_id`, `keyword`, `department_id`, `position_id`, `employment_status`, `employment_type`, `page`, `page_size`, `sort_by`, `sort_order`
- response key: `data.items[]`, `data.pagination`

## `GET https://lemma-backend-staging-staging.up.railway.app/api/legal/documents`
- method: `GET`
- auth: `Bearer JWT` required
- query params: `org_id`, `company_id`, `branch_id`, `keyword`, `document_type`, `signing_status`, `page`, `page_size`, `sort_by`, `sort_order`
- response key: `data.items[]`
