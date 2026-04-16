# Leave Canonical API Staging Smoke v1

## Goal

Verify that `/hr/leave` can switch from fallback/mock to canonical backend routes in staging.

## Preconditions

- staging backend deployment
- valid bearer token
- selected context resolves to a readable company scope
- at least one leave request exists in scope

## Read-Only Smoke

1. `GET /api/hr/leave/requests`
   - expect `200`
   - expect `schema_version = hr.leave.request.list.v1`
   - expect `data.items[]`
   - expect `data.scope.org_id/company_id/environment_type`

2. `GET /api/hr/leave/requests?approval_status=pending`
   - expect `200`
   - expect filtered items only

3. `GET /api/hr/leave/requests?keyword=<employee_code_or_name>`
   - expect `200`
   - expect keyword filter to work

4. `GET /api/hr/leave/requests/:id`
   - expect `200`
   - expect `data.leave_request`
   - expect `data.employee`
   - expect `data.approval_logs[]`
   - expect `data.attachments[]`

## Write Skeleton Smoke

1. `POST /api/hr/leave/requests`
   - staging only
   - expect `201` for writable admin scope
   - expect `403` for non-writable scope

2. `POST /api/hr/leave/requests/:id/approve`
   - expect `200` for writable admin scope

3. `POST /api/hr/leave/requests/:id/reject`
   - missing reason should return `400`
   - valid reason should return `200`

4. `POST /api/hr/leave/requests/:id/cancel`
   - expect `200` for writable admin scope

## Protection Smoke

1. production runtime
   - every leave canonical route should return `403 STAGING_ONLY`

2. wrong selected context
   - request should not leak cross-org leave requests

3. demo context
   - read may work if membership/RLS allows
   - write should remain blocked by staging rollout policy
