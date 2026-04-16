-- Sprint 2B.11.2 - Feature Gating Data Source (minimal)
-- Scope: override table only, no billing/plan/subscription engine

create table if not exists organization_features (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  feature_key text not null,
  is_enabled boolean not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  unique (org_id, feature_key)
);

create index if not exists organization_features_org_idx
on organization_features (org_id, feature_key);

alter table organization_features enable row level security;

-- Minimal override to preserve current behavior:
-- Demo org keeps external API standard disabled.
insert into organization_features (org_id, feature_key, is_enabled, reason)
values (
  '10000000-0000-0000-0000-000000000002',
  'attendance.external_api.standard',
  false,
  'demo scope override'
)
on conflict (org_id, feature_key) do update
set
  is_enabled = excluded.is_enabled,
  reason = excluded.reason,
  updated_at = now();
