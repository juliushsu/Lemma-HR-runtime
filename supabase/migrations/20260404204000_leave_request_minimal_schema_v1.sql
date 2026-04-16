-- Leave request minimal schema + functions + RLS (staging rollout target)
-- Contract base: leave_request_minimal_contract_v1

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
create or replace function public.leave_current_employee_id()
returns uuid
language sql
stable
as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb ->> 'employee_id'), '')::uuid
$$;

create or replace function public.leave_can_company_read(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner', 'super_admin', 'admin', 'manager')
      and m.scope_type::text in ('org', 'company')
  )
$$;

create or replace function public.leave_can_approve_scope(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type::text = row_environment_type
      and m.role::text in ('owner', 'admin', 'manager')
      and m.scope_type::text in ('org', 'company')
  )
$$;

create or replace function public.leave_is_self_employee(
  row_employee_id uuid,
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text
)
returns boolean
language sql
stable
as $$
  select
    leave_current_employee_id() is not null
    and leave_current_employee_id() = row_employee_id
    and exists (
      select 1
      from public.memberships m
      where m.user_id = auth.uid()
        and m.org_id = row_org_id
        and (m.company_id is null or m.company_id = row_company_id)
        and m.environment_type::text = row_environment_type
        and m.scope_type::text in ('self', 'org', 'company')
    )
$$;

-- -----------------------------------------------------------------------------
-- 1) leave_requests
-- -----------------------------------------------------------------------------
create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  environment_type text not null check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  leave_type text not null check (leave_type in (
    'annual_leave',
    'sick_leave',
    'personal_leave',
    'unpaid_leave',
    'maternity_leave',
    'bereavement_leave',
    'official_leave',
    'other'
  )),
  start_date date not null,
  end_date date not null,
  start_time time,
  end_time time,
  duration_hours numeric(10,2),
  duration_days numeric(10,2),
  reason text not null,

  approver_user_id uuid references public.users(id) on delete set null,
  approval_status text not null default 'pending' check (approval_status in ('draft', 'pending', 'approved', 'rejected', 'cancelled')),
  approved_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,

  affects_payroll boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

alter table public.leave_requests
  add column if not exists environment_type text,
  add column if not exists is_demo boolean,
  add column if not exists created_by uuid,
  add column if not exists updated_by uuid;

update public.leave_requests
set environment_type = 'production'
where environment_type is null;

update public.leave_requests
set is_demo = false
where is_demo is null;

update public.leave_requests
set approval_status = 'pending'
where approval_status = 'submitted';

alter table public.leave_requests
  alter column environment_type set default 'production',
  alter column environment_type set not null,
  alter column is_demo set default false,
  alter column is_demo set not null,
  alter column approval_status set default 'pending';

alter table public.leave_requests
  drop constraint if exists leave_requests_approval_status_check;

alter table public.leave_requests
  add constraint leave_requests_approval_status_check
  check (approval_status in ('draft', 'pending', 'approved', 'rejected', 'cancelled'));

create index if not exists leave_requests_scope_idx
  on public.leave_requests (org_id, company_id, environment_type, approval_status, start_date, end_date);
create index if not exists leave_requests_employee_range_idx
  on public.leave_requests (employee_id, start_date desc, created_at desc);
create index if not exists leave_requests_approver_idx
  on public.leave_requests (approver_user_id, updated_at desc);

-- -----------------------------------------------------------------------------
-- 2) leave_approval_logs (append-only)
-- -----------------------------------------------------------------------------
create table if not exists public.leave_approval_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  leave_request_id uuid not null references public.leave_requests(id) on delete cascade,

  actor_user_id uuid not null references public.users(id) on delete restrict,
  actor_role text,
  action text not null check (action in ('submitted', 'approved', 'rejected', 'cancelled', 'reopened')),
  from_status text,
  to_status text not null check (to_status in ('draft', 'pending', 'approved', 'rejected', 'cancelled')),
  reason text,

  created_at timestamptz not null default now(),
  created_by uuid
);

create index if not exists leave_approval_logs_scope_idx
  on public.leave_approval_logs (org_id, company_id, created_at desc);
create index if not exists leave_approval_logs_leave_request_idx
  on public.leave_approval_logs (leave_request_id, created_at asc);

-- -----------------------------------------------------------------------------
-- 3) leave_request_attachments (metadata only)
-- -----------------------------------------------------------------------------
create table if not exists public.leave_request_attachments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  leave_request_id uuid not null references public.leave_requests(id) on delete cascade,
  storage_bucket text not null,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  file_size_bytes bigint,
  created_at timestamptz not null default now(),
  created_by uuid
);

create index if not exists leave_request_attachments_scope_idx
  on public.leave_request_attachments (org_id, company_id, created_at desc);
create index if not exists leave_request_attachments_leave_request_idx
  on public.leave_request_attachments (leave_request_id, created_at asc);

create or replace function public.leave_can_access_request(
  row_leave_request_id uuid
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.leave_requests lr
    where lr.id = row_leave_request_id
      and (
        leave_can_company_read(lr.org_id, lr.company_id, lr.environment_type)
        or leave_is_self_employee(lr.employee_id, lr.org_id, lr.company_id, lr.environment_type)
      )
  )
$$;

create or replace function public.leave_can_write_request(
  row_leave_request_id uuid
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.leave_requests lr
    where lr.id = row_leave_request_id
      and (
        leave_can_approve_scope(lr.org_id, lr.company_id, lr.environment_type)
        or leave_is_self_employee(lr.employee_id, lr.org_id, lr.company_id, lr.environment_type)
      )
  )
$$;

create or replace function public.leave_can_append_log(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text,
  row_leave_request_id uuid,
  row_actor_user_id uuid,
  row_action text
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.leave_requests lr
    where lr.id = row_leave_request_id
      and lr.org_id = row_org_id
      and lr.company_id = row_company_id
      and lr.environment_type = row_environment_type
      and (
        (
          auth.uid() is not null
          and row_actor_user_id = auth.uid()
          and leave_can_approve_scope(row_org_id, row_company_id, row_environment_type)
        )
        or (
          auth.uid() is not null
          and row_actor_user_id = auth.uid()
          and row_action in ('submitted', 'cancelled')
          and leave_is_self_employee(lr.employee_id, row_org_id, row_company_id, row_environment_type)
        )
      )
  )
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.leave_requests enable row level security;
alter table public.leave_approval_logs enable row level security;
alter table public.leave_request_attachments enable row level security;

-- leave_requests
drop policy if exists leave_requests_company_read on public.leave_requests;
drop policy if exists leave_requests_member_select on public.leave_requests;
create policy leave_requests_company_read
on public.leave_requests
for select
using (leave_can_company_read(org_id, company_id, environment_type));

drop policy if exists leave_requests_self_read on public.leave_requests;
create policy leave_requests_self_read
on public.leave_requests
for select
using (leave_is_self_employee(employee_id, org_id, company_id, environment_type));

drop policy if exists leave_requests_company_insert on public.leave_requests;
drop policy if exists leave_requests_member_insert on public.leave_requests;
create policy leave_requests_company_insert
on public.leave_requests
for insert
with check (leave_can_approve_scope(org_id, company_id, environment_type));

drop policy if exists leave_requests_self_insert on public.leave_requests;
create policy leave_requests_self_insert
on public.leave_requests
for insert
with check (leave_is_self_employee(employee_id, org_id, company_id, environment_type));

drop policy if exists leave_requests_company_update on public.leave_requests;
drop policy if exists leave_requests_approver_update on public.leave_requests;
create policy leave_requests_company_update
on public.leave_requests
for update
using (leave_can_approve_scope(org_id, company_id, environment_type))
with check (leave_can_approve_scope(org_id, company_id, environment_type));

drop policy if exists leave_requests_self_cancel_update on public.leave_requests;
create policy leave_requests_self_cancel_update
on public.leave_requests
for update
using (
  leave_is_self_employee(employee_id, org_id, company_id, environment_type)
  and approval_status in ('draft', 'pending')
)
with check (
  leave_is_self_employee(employee_id, org_id, company_id, environment_type)
  and approval_status = 'cancelled'
);

-- leave_approval_logs
drop policy if exists leave_approval_logs_read on public.leave_approval_logs;
create policy leave_approval_logs_read
on public.leave_approval_logs
for select
using (leave_can_access_request(leave_request_id));

drop policy if exists leave_approval_logs_insert on public.leave_approval_logs;
create policy leave_approval_logs_insert
on public.leave_approval_logs
for insert
with check (
  leave_can_append_log(
    org_id,
    company_id,
    (select lr.environment_type from public.leave_requests lr where lr.id = leave_request_id),
    leave_request_id,
    actor_user_id,
    action
  )
);

-- leave_request_attachments
drop policy if exists leave_request_attachments_read on public.leave_request_attachments;
create policy leave_request_attachments_read
on public.leave_request_attachments
for select
using (leave_can_access_request(leave_request_id));

drop policy if exists leave_request_attachments_insert on public.leave_request_attachments;
create policy leave_request_attachments_insert
on public.leave_request_attachments
for insert
with check (leave_can_write_request(leave_request_id));

-- -----------------------------------------------------------------------------
-- Utility: actor role
-- -----------------------------------------------------------------------------
create or replace function public.leave_actor_role(
  p_user_id uuid,
  p_org_id uuid,
  p_company_id uuid,
  p_environment_type text
)
returns text
language sql
stable
as $$
  select m.role::text
  from public.memberships m
  where m.user_id = p_user_id
    and m.org_id = p_org_id
    and (m.company_id is null or m.company_id = p_company_id)
    and m.environment_type::text = p_environment_type
  order by
    case m.role::text
      when 'owner' then 1
      when 'super_admin' then 2
      when 'admin' then 3
      when 'manager' then 4
      when 'operator' then 5
      when 'viewer' then 6
      else 9
    end
  limit 1
$$;

-- -----------------------------------------------------------------------------
-- Functions
-- -----------------------------------------------------------------------------
create or replace function public.list_leave_requests(
  p_org_id uuid,
  p_company_id uuid
)
returns table (
  leave_request_id uuid,
  employee_id uuid,
  employee_code text,
  employee_display_name text,
  leave_type text,
  start_date date,
  end_date date,
  start_time time,
  end_time time,
  duration_hours numeric,
  duration_days numeric,
  reason text,
  approver_user_id uuid,
  approval_status text,
  approved_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,
  affects_payroll boolean,
  created_at timestamptz,
  updated_at timestamptz,
  last_action text,
  last_action_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    lr.id as leave_request_id,
    lr.employee_id,
    e.employee_code,
    coalesce(e.display_name, e.preferred_name, e.legal_name) as employee_display_name,
    lr.leave_type,
    lr.start_date,
    lr.end_date,
    lr.start_time,
    lr.end_time,
    lr.duration_hours,
    lr.duration_days,
    lr.reason,
    lr.approver_user_id,
    lr.approval_status,
    lr.approved_at,
    lr.rejected_at,
    lr.rejection_reason,
    lr.affects_payroll,
    lr.created_at,
    lr.updated_at,
    lg.action as last_action,
    lg.created_at as last_action_at
  from public.leave_requests lr
  left join public.employees e on e.id = lr.employee_id
  left join lateral (
    select l.action, l.created_at
    from public.leave_approval_logs l
    where l.leave_request_id = lr.id
    order by l.created_at desc
    limit 1
  ) lg on true
  where lr.org_id = p_org_id
    and lr.company_id = p_company_id
  order by lr.created_at desc;
$$;

create or replace function public.get_leave_request_detail(
  p_leave_request_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_lr public.leave_requests%rowtype;
begin
  select *
    into v_lr
  from public.leave_requests
  where id = p_leave_request_id;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'leave_request', to_jsonb(v_lr),
    'employee', (
      select to_jsonb(e)
      from (
        select
          e.id,
          e.employee_code,
          e.display_name,
          e.preferred_name,
          e.legal_name
        from public.employees e
        where e.id = v_lr.employee_id
      ) e
    ),
    'approval_logs', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.created_at asc)
      from public.leave_approval_logs l
      where l.leave_request_id = p_leave_request_id
    ), '[]'::jsonb),
    'attachments', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at asc)
      from public.leave_request_attachments a
      where a.leave_request_id = p_leave_request_id
    ), '[]'::jsonb)
  );
end;
$$;

drop function if exists public.create_leave_request(jsonb);
create function public.create_leave_request(
  p_payload jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := auth.uid();
  v_employee_id uuid := nullif(p_payload ->> 'employee_id', '')::uuid;
  v_org_id uuid := nullif(p_payload ->> 'org_id', '')::uuid;
  v_company_id uuid := nullif(p_payload ->> 'company_id', '')::uuid;
  v_environment_type text := nullif(p_payload ->> 'environment_type', '');
  v_is_demo boolean := coalesce((p_payload ->> 'is_demo')::boolean, false);
  v_leave_type text := nullif(p_payload ->> 'leave_type', '');
  v_start_date date := nullif(p_payload ->> 'start_date', '')::date;
  v_end_date date := nullif(p_payload ->> 'end_date', '')::date;
  v_start_time time := nullif(p_payload ->> 'start_time', '')::time;
  v_end_time time := nullif(p_payload ->> 'end_time', '')::time;
  v_duration_hours numeric := nullif(p_payload ->> 'duration_hours', '')::numeric;
  v_duration_days numeric := nullif(p_payload ->> 'duration_days', '')::numeric;
  v_reason text := nullif(trim(coalesce(p_payload ->> 'reason', '')), '');
  v_affects_payroll boolean := coalesce((p_payload ->> 'affects_payroll')::boolean, false);
  v_employee public.employees%rowtype;
  v_leave public.leave_requests%rowtype;
begin
  if v_employee_id is null then
    raise exception 'EMPLOYEE_ID_REQUIRED';
  end if;
  if v_leave_type is null then
    raise exception 'LEAVE_TYPE_REQUIRED';
  end if;
  if v_start_date is null or v_end_date is null then
    raise exception 'LEAVE_DATE_REQUIRED';
  end if;
  if v_reason is null then
    raise exception 'LEAVE_REASON_REQUIRED';
  end if;
  if v_start_date > v_end_date then
    raise exception 'INVALID_LEAVE_DATE_RANGE';
  end if;

  select *
    into v_employee
  from public.employees
  where id = v_employee_id;

  if not found then
    raise exception 'EMPLOYEE_NOT_FOUND';
  end if;

  v_org_id := coalesce(v_org_id, v_employee.org_id);
  v_company_id := coalesce(v_company_id, v_employee.company_id);
  v_environment_type := coalesce(v_environment_type, v_employee.environment_type);
  v_is_demo := coalesce((p_payload ->> 'is_demo')::boolean, v_employee.is_demo);

  if v_org_id <> v_employee.org_id or v_company_id <> v_employee.company_id then
    raise exception 'EMPLOYEE_SCOPE_MISMATCH';
  end if;

  if v_environment_type not in ('production', 'demo', 'sandbox', 'seed') then
    raise exception 'INVALID_ENVIRONMENT_TYPE';
  end if;

  if v_actor_user_id is null then
    v_actor_user_id := nullif(p_payload ->> 'actor_user_id', '')::uuid;
  end if;

  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_ID_REQUIRED';
  end if;

  insert into public.leave_requests (
    org_id,
    company_id,
    employee_id,
    environment_type,
    is_demo,
    leave_type,
    start_date,
    end_date,
    start_time,
    end_time,
    duration_hours,
    duration_days,
    reason,
    approver_user_id,
    approval_status,
    approved_at,
    rejected_at,
    rejection_reason,
    affects_payroll,
    created_by,
    updated_by
  ) values (
    v_org_id,
    v_company_id,
    v_employee_id,
    v_environment_type,
    v_is_demo,
    v_leave_type,
    v_start_date,
    v_end_date,
    v_start_time,
    v_end_time,
    v_duration_hours,
    v_duration_days,
    v_reason,
    null,
    'pending',
    null,
    null,
    null,
    v_affects_payroll,
    v_actor_user_id,
    v_actor_user_id
  )
  returning *
    into v_leave;

  insert into public.leave_approval_logs (
    org_id,
    company_id,
    leave_request_id,
    actor_user_id,
    actor_role,
    action,
    from_status,
    to_status,
    reason,
    created_at,
    created_by
  ) values (
    v_leave.org_id,
    v_leave.company_id,
    v_leave.id,
    v_actor_user_id,
    coalesce(public.leave_actor_role(v_actor_user_id, v_leave.org_id, v_leave.company_id, v_leave.environment_type), 'employee'),
    'submitted',
    null,
    'pending',
    v_reason,
    now(),
    v_actor_user_id
  );

  return jsonb_build_object(
    'leave_request_id', v_leave.id,
    'approval_status', v_leave.approval_status,
    'employee_id', v_leave.employee_id,
    'leave_type', v_leave.leave_type,
    'start_date', v_leave.start_date,
    'end_date', v_leave.end_date,
    'created_at', v_leave.created_at
  );
end;
$$;

drop function if exists public.approve_leave_request(uuid, uuid, text);
create function public.approve_leave_request(
  p_leave_request_id uuid,
  p_approver_user_id uuid,
  p_reason text default null
)
returns table (
  leave_request_id uuid,
  approval_status text,
  approver_user_id uuid,
  approved_at timestamptz,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_approver_user_id);
  v_from_status text;
begin
  if auth.uid() is not null and p_approver_user_id is not null and p_approver_user_id <> auth.uid() then
    raise exception 'APPROVER_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'APPROVER_USER_REQUIRED';
  end if;

  select lr.approval_status
    into v_from_status
  from public.leave_requests lr
  where lr.id = p_leave_request_id
  for update;

  if not found then
    raise exception 'LEAVE_REQUEST_NOT_FOUND';
  end if;
  if v_from_status = 'approved' then
    raise exception 'LEAVE_REQUEST_ALREADY_APPROVED';
  end if;
  if v_from_status = 'cancelled' then
    raise exception 'LEAVE_REQUEST_ALREADY_CANCELLED';
  end if;

  update public.leave_requests lr
  set
    approver_user_id = v_actor_user_id,
    approval_status = 'approved',
    approved_at = now(),
    rejected_at = null,
    rejection_reason = null,
    updated_at = now(),
    updated_by = v_actor_user_id
  where lr.id = p_leave_request_id;

  insert into public.leave_approval_logs (
    org_id,
    company_id,
    leave_request_id,
    actor_user_id,
    actor_role,
    action,
    from_status,
    to_status,
    reason,
    created_at,
    created_by
  )
  select
    lr.org_id,
    lr.company_id,
    lr.id,
    v_actor_user_id,
    coalesce(public.leave_actor_role(v_actor_user_id, lr.org_id, lr.company_id, lr.environment_type), 'manager'),
    'approved',
    v_from_status,
    'approved',
    nullif(trim(coalesce(p_reason, '')), ''),
    now(),
    v_actor_user_id
  from public.leave_requests lr
  where lr.id = p_leave_request_id;

  return query
  select
    lr.id as leave_request_id,
    lr.approval_status,
    lr.approver_user_id,
    lr.approved_at,
    lr.updated_at
  from public.leave_requests lr
  where lr.id = p_leave_request_id;
end;
$$;

drop function if exists public.reject_leave_request(uuid, uuid, text);
create function public.reject_leave_request(
  p_leave_request_id uuid,
  p_approver_user_id uuid,
  p_rejection_reason text
)
returns table (
  leave_request_id uuid,
  approval_status text,
  approver_user_id uuid,
  rejected_at timestamptz,
  rejection_reason text,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_approver_user_id);
  v_from_status text;
  v_reason text := nullif(trim(coalesce(p_rejection_reason, '')), '');
begin
  if v_reason is null then
    raise exception 'REJECTION_REASON_REQUIRED';
  end if;
  if auth.uid() is not null and p_approver_user_id is not null and p_approver_user_id <> auth.uid() then
    raise exception 'APPROVER_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'APPROVER_USER_REQUIRED';
  end if;

  select lr.approval_status
    into v_from_status
  from public.leave_requests lr
  where lr.id = p_leave_request_id
  for update;

  if not found then
    raise exception 'LEAVE_REQUEST_NOT_FOUND';
  end if;
  if v_from_status = 'cancelled' then
    raise exception 'LEAVE_REQUEST_ALREADY_CANCELLED';
  end if;

  update public.leave_requests lr
  set
    approver_user_id = v_actor_user_id,
    approval_status = 'rejected',
    rejected_at = now(),
    rejection_reason = v_reason,
    approved_at = null,
    updated_at = now(),
    updated_by = v_actor_user_id
  where lr.id = p_leave_request_id;

  insert into public.leave_approval_logs (
    org_id,
    company_id,
    leave_request_id,
    actor_user_id,
    actor_role,
    action,
    from_status,
    to_status,
    reason,
    created_at,
    created_by
  )
  select
    lr.org_id,
    lr.company_id,
    lr.id,
    v_actor_user_id,
    coalesce(public.leave_actor_role(v_actor_user_id, lr.org_id, lr.company_id, lr.environment_type), 'manager'),
    'rejected',
    v_from_status,
    'rejected',
    v_reason,
    now(),
    v_actor_user_id
  from public.leave_requests lr
  where lr.id = p_leave_request_id;

  return query
  select
    lr.id as leave_request_id,
    lr.approval_status,
    lr.approver_user_id,
    lr.rejected_at,
    lr.rejection_reason,
    lr.updated_at
  from public.leave_requests lr
  where lr.id = p_leave_request_id;
end;
$$;

drop function if exists public.cancel_leave_request(uuid, uuid);
create function public.cancel_leave_request(
  p_leave_request_id uuid,
  p_actor_user_id uuid
)
returns table (
  leave_request_id uuid,
  approval_status text,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_actor_user_id);
  v_from_status text;
begin
  if auth.uid() is not null and p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  select lr.approval_status
    into v_from_status
  from public.leave_requests lr
  where lr.id = p_leave_request_id
  for update;

  if not found then
    raise exception 'LEAVE_REQUEST_NOT_FOUND';
  end if;
  if v_from_status = 'cancelled' then
    raise exception 'LEAVE_REQUEST_ALREADY_CANCELLED';
  end if;

  update public.leave_requests lr
  set
    approval_status = 'cancelled',
    updated_at = now(),
    updated_by = v_actor_user_id
  where lr.id = p_leave_request_id;

  insert into public.leave_approval_logs (
    org_id,
    company_id,
    leave_request_id,
    actor_user_id,
    actor_role,
    action,
    from_status,
    to_status,
    reason,
    created_at,
    created_by
  )
  select
    lr.org_id,
    lr.company_id,
    lr.id,
    v_actor_user_id,
    coalesce(public.leave_actor_role(v_actor_user_id, lr.org_id, lr.company_id, lr.environment_type), 'employee'),
    'cancelled',
    v_from_status,
    'cancelled',
    null,
    now(),
    v_actor_user_id
  from public.leave_requests lr
  where lr.id = p_leave_request_id;

  return query
  select
    lr.id as leave_request_id,
    lr.approval_status,
    lr.updated_at
  from public.leave_requests lr
  where lr.id = p_leave_request_id;
end;
$$;

grant execute on function public.list_leave_requests(uuid, uuid) to authenticated, service_role;
grant execute on function public.get_leave_request_detail(uuid) to authenticated, service_role;
grant execute on function public.create_leave_request(jsonb) to authenticated, service_role;
grant execute on function public.approve_leave_request(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.reject_leave_request(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.cancel_leave_request(uuid, uuid) to authenticated, service_role;
