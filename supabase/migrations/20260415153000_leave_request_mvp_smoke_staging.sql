-- STAGING ONLY: leave request MVP smoke scaffolding
-- Intention:
-- 1) keep existing richer public.leave_requests contract untouched when it already exists
-- 2) create minimal public.leave_requests only on clean databases
-- 3) add public.leave_approval_steps for staging smoke without RLS / triggers / complex validation

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),

  company_id uuid not null,
  employee_id uuid not null,

  leave_type text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,

  status text not null default 'pending',
  current_step int default 0,

  created_at timestamptz default now()
);

create table if not exists public.leave_approval_steps (
  id uuid primary key default gen_random_uuid(),

  request_id uuid references public.leave_requests(id) on delete cascade,

  step_order int not null,
  approver_employee_id uuid not null,

  status text default 'pending',
  acted_at timestamptz,
  comment text
);
