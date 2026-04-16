# System RBAC Frontend Alignment (Quick)

## Roles
- `owner`
- `super_admin`
- `admin`
- `viewer`

## System Sidebar Visibility
- `owner`: visible
- `super_admin`: visible
- `admin`: hidden
- `viewer`: hidden

## System Route Access
- `owner`: allow
- `super_admin`: allow (restricted actions)
- `admin`: deny (`403`)
- `viewer`: deny (`403`)

## Full vs Limited Principle
- `full` (`owner`): can perform all system actions.
- `limited` (`super_admin`): can view system pages and perform non-owner-safe actions only; cannot execute owner-only operations.
