-- STAGING ONLY: marketing intake minimal flow
-- request-demo / apply-access

create table if not exists public.intake_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  company text not null,
  role text null,
  team_size text null,
  message text null,
  request_type text not null default 'request_demo'
    check (request_type in ('request_demo','apply_access','other')),
  source_path text null,
  email_delivery_status text not null default 'pending'
    check (email_delivery_status in ('pending','sent','failed','not_configured')),
  email_delivery_error text null,
  created_at timestamptz not null default now()
);

create index if not exists intake_requests_created_at_idx
  on public.intake_requests (created_at desc);

create index if not exists intake_requests_email_idx
  on public.intake_requests (lower(email));

alter table public.intake_requests enable row level security;

drop policy if exists intake_requests_select_policy on public.intake_requests;
create policy intake_requests_select_policy
on public.intake_requests
for select
using (
  exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.role::text in ('owner','super_admin','admin')
  )
);

-- No anon/authenticated insert directly to table; write via backend route only.
