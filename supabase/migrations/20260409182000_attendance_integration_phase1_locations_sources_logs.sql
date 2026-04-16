-- =========================================
-- Lemma HR+ Attendance Integration Phase 1
-- locations / attendance_sources / attendance_logs
-- staging-first additive migration
-- =========================================

create extension if not exists pgcrypto;

-- 1) locations
create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  company_id uuid not null,

  code text,
  name text not null,
  address text,

  latitude numeric(10,7),
  longitude numeric(10,7),
  checkin_radius_m integer,

  is_attendance_enabled boolean not null default true,
  is_active boolean not null default true,

  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_locations_org_company
  on public.locations (org_id, company_id);

create unique index if not exists uq_locations_org_company_code
  on public.locations (org_id, company_id, code)
  where code is not null;

-- 2) attendance_source_types
create table if not exists public.attendance_source_types (
  key text primary key,
  label_zh text not null,
  label_en text not null,
  label_ja text not null,
  sort_order integer not null default 100,
  is_built_in boolean not null default true
);

insert into public.attendance_source_types (key, label_zh, label_en, label_ja, sort_order, is_built_in)
values
  ('line_bot', 'LINE 打卡', 'LINE Check-in', 'LINE打刻', 10, true),
  ('external_api', '外部系統', 'External System', '外部システム', 20, true),
  ('timesheet_upload', '打卡單上傳', 'Timesheet Upload', '打刻表アップロード', 30, true),
  ('face_recognition', '人臉辨識', 'Face Recognition', '顔認識', 40, true),
  ('rfid', 'RFID 感應卡', 'RFID Card', 'RFIDカード', 50, true)
on conflict (key) do nothing;

-- 3) attendance_sources
create table if not exists public.attendance_sources (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  company_id uuid not null,

  source_key text not null references public.attendance_source_types(key),
  is_enabled boolean not null default false,
  config jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (org_id, company_id, source_key)
);

create index if not exists idx_attendance_sources_org_company
  on public.attendance_sources (org_id, company_id);

-- 4) attendance_source_location_bindings
create table if not exists public.attendance_source_location_bindings (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  company_id uuid not null,

  attendance_source_id uuid not null references public.attendance_sources(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete cascade,

  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),

  unique (attendance_source_id, location_id)
);

create index if not exists idx_attendance_source_location_bindings_scope
  on public.attendance_source_location_bindings (org_id, company_id, attendance_source_id, is_enabled);

-- 5) attendance_logs (additive compatibility on top of existing HR MVP table)
alter table public.attendance_logs
  add column if not exists location_id uuid references public.locations(id),
  add column if not exists attendance_source_id uuid references public.attendance_sources(id),
  add column if not exists source_key text,
  add column if not exists gps_latitude numeric(10,7),
  add column if not exists gps_longitude numeric(10,7),
  add column if not exists distance_m numeric(10,2),
  add column if not exists is_within_range boolean,
  add column if not exists record_source text not null default 'system',
  add column if not exists status_color text,
  add column if not exists raw_payload jsonb not null default '{}'::jsonb,
  add column if not exists notes text;

update public.attendance_logs
set source_key = coalesce(source_key, source_type)
where source_key is null;

create index if not exists idx_attendance_logs_org_company_checked_at
  on public.attendance_logs (org_id, company_id, checked_at desc);

create index if not exists idx_attendance_logs_employee_checked_at
  on public.attendance_logs (employee_id, checked_at desc);

-- 6) attendance_adjustments (additive compatibility on top of existing HR MVP table)
alter table public.attendance_adjustments
  add column if not exists requested_by uuid,
  add column if not exists approved_by uuid,
  add column if not exists before_payload jsonb not null default '{}'::jsonb,
  add column if not exists after_payload jsonb not null default '{}'::jsonb,
  add column if not exists status text default 'pending';

-- 7) updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_locations_updated_at on public.locations;
create trigger trg_locations_updated_at
before update on public.locations
for each row execute function public.set_updated_at();

drop trigger if exists trg_attendance_sources_updated_at on public.attendance_sources;
create trigger trg_attendance_sources_updated_at
before update on public.attendance_sources
for each row execute function public.set_updated_at();

drop trigger if exists trg_attendance_logs_updated_at on public.attendance_logs;
create trigger trg_attendance_logs_updated_at
before update on public.attendance_logs
for each row execute function public.set_updated_at();

drop trigger if exists trg_attendance_adjustments_updated_at on public.attendance_adjustments;
create trigger trg_attendance_adjustments_updated_at
before update on public.attendance_adjustments
for each row execute function public.set_updated_at();
