-- STAGING ONLY: align existing leave_requests table with leave request MVP smoke route

alter table if exists public.leave_requests
  add column if not exists start_at timestamptz,
  add column if not exists end_at timestamptz,
  add column if not exists status text,
  add column if not exists current_step int;

update public.leave_requests
set start_at = coalesce(start_at, start_date::timestamptz)
where start_at is null
  and start_date is not null;

update public.leave_requests
set end_at = coalesce(end_at, end_date::timestamptz)
where end_at is null
  and end_date is not null;

update public.leave_requests
set status = coalesce(status, approval_status, 'pending')
where status is null;

update public.leave_requests
set current_step = coalesce(current_step, 0)
where current_step is null;

alter table if exists public.leave_requests
  alter column status set default 'pending',
  alter column current_step set default 0;
