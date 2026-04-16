# Sign-out Smoke Checklist (Frontend)

Last updated: 2026-04-01 (Asia/Taipei)

## 1) Protected Route Inventory

This repository is backend-focused and does not contain Readdy frontend route code, so AuthGuard wrapping cannot be confirmed directly here.

Expected protected frontend pages (must redirect to `/login` after sign-out):
- `/dashboard`
- `/hr/employees`
- `/settings`
- `/legal/documents`

Backend protected API baseline (requires Bearer token):
- `GET /api/me`
- `GET /api/hr/employees`
- `GET /api/legal/documents`

## 2) AuthGuard Verification Checklist

For each frontend page above, verify:
- Route is wrapped by AuthGuard (or equivalent route middleware).
- Missing/expired session triggers redirect to `/login`.
- Protected page content is not rendered before guard decision completes.
- Browser refresh on protected page while logged out still redirects to `/login`.

## 3) Sign-out Smoke Steps

1. Login with a valid account (for example `staging.superadmin@lemma.local`).
2. Open:
   - `/dashboard`
   - `/hr/employees`
   - `/settings`
   - `/legal/documents`
3. Click sign out.
4. Expected immediately:
   - current page redirects to `/login`.
   - auth storage is cleared (access token/session removed).
5. Manually revisit each protected page URL.
6. Expected for each revisit:
   - redirected to `/login` (no protected content flash).
7. Call API without token:
   - `GET /api/me` -> `401`
   - `GET /api/hr/employees` -> `401`
   - `GET /api/legal/documents` -> `401`

## 4) Failure Template

Use this format when reporting a failure:
- route:
- expected:
- actual:
- network status:
- root cause:
- fix owner:

