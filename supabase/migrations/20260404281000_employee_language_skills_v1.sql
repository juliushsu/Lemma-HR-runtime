-- Employee language skills v1 (staging)
-- Scope: minimal table + RLS + read/write functions.

create extension if not exists pgcrypto;

create table if not exists public.employee_language_skills (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  environment_type text not null check (environment_type in ('production', 'demo', 'sandbox', 'seed')),
  is_demo boolean not null default false,

  language_code text not null,
  proficiency_level text not null check (proficiency_level in ('basic', 'conversational', 'business', 'native')),
  skill_type text not null check (skill_type in ('spoken', 'written', 'reading', 'other')),
  is_primary boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (employee_id, language_code, skill_type, environment_type)
);

create index if not exists employee_language_skills_scope_idx
  on public.employee_language_skills (org_id, company_id, environment_type, employee_id);

create unique index if not exists employee_language_skills_one_primary_idx
  on public.employee_language_skills (employee_id, environment_type)
  where is_primary = true;

create or replace function public.employee_language_can_read(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type text,
  row_employee_id uuid
)
returns boolean
language sql
stable
as $$
  select
    exists (
      select 1
      from public.memberships m
      where m.user_id = auth.uid()
        and m.org_id = row_org_id
        and (m.company_id is null or m.company_id = row_company_id)
        and m.environment_type::text = row_environment_type
        and m.role::text in ('owner', 'admin', 'manager')
        and m.scope_type::text in ('org', 'company', 'branch')
    )
    or (
      row_employee_id = public.current_jwt_employee_id()
      and exists (
        select 1
        from public.memberships m
        where m.user_id = auth.uid()
          and m.org_id = row_org_id
          and (m.company_id is null or m.company_id = row_company_id)
          and m.environment_type::text = row_environment_type
          and m.scope_type::text in ('self', 'org', 'company', 'branch')
      )
    )
$$;

create or replace function public.employee_language_can_write(
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
      and m.scope_type::text in ('org', 'company', 'branch')
  )
$$;

create or replace function public.employee_language_can_delete(
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
      and m.role::text in ('owner', 'admin')
      and m.scope_type::text in ('org', 'company', 'branch')
  )
$$;

alter table public.employee_language_skills enable row level security;

drop policy if exists employee_language_skills_select_policy on public.employee_language_skills;
create policy employee_language_skills_select_policy
on public.employee_language_skills
for select
using (public.employee_language_can_read(org_id, company_id, environment_type, employee_id));

drop policy if exists employee_language_skills_insert_policy on public.employee_language_skills;
create policy employee_language_skills_insert_policy
on public.employee_language_skills
for insert
with check (public.employee_language_can_write(org_id, company_id, environment_type));

drop policy if exists employee_language_skills_update_policy on public.employee_language_skills;
create policy employee_language_skills_update_policy
on public.employee_language_skills
for update
using (public.employee_language_can_write(org_id, company_id, environment_type))
with check (public.employee_language_can_write(org_id, company_id, environment_type));

drop policy if exists employee_language_skills_delete_policy on public.employee_language_skills;
create policy employee_language_skills_delete_policy
on public.employee_language_skills
for delete
using (public.employee_language_can_delete(org_id, company_id, environment_type));

grant select, insert, update, delete on table public.employee_language_skills to authenticated, service_role;

drop function if exists public.list_employee_language_skills(text);
create function public.list_employee_language_skills(
  p_employee_id_or_code text
)
returns table (
  id uuid,
  employee_id uuid,
  employee_code text,
  language_code text,
  proficiency_level text,
  skill_type text,
  is_primary boolean,
  updated_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(p_employee_id_or_code, '')), '');
  v_ref_uuid uuid;
begin
  if v_ref is null then
    return;
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  return query
  with target as (
    select e.*
    from public.employees e
    where (v_ref_uuid is not null and e.id = v_ref_uuid)
       or upper(e.employee_code) = upper(v_ref)
    order by case when v_ref_uuid is not null and e.id = v_ref_uuid then 0 else 1 end
    limit 1
  )
  select
    s.id,
    s.employee_id,
    t.employee_code,
    s.language_code,
    s.proficiency_level,
    s.skill_type,
    s.is_primary,
    s.updated_at
  from public.employee_language_skills s
  join target t
    on s.employee_id = t.id
   and s.org_id = t.org_id
   and s.company_id = t.company_id
   and s.environment_type = t.environment_type
  order by s.is_primary desc, s.language_code asc, s.skill_type asc;
end;
$$;

drop function if exists public.upsert_employee_language_skill(jsonb);
create function public.upsert_employee_language_skill(
  p_payload jsonb
)
returns table (
  id uuid,
  employee_id uuid,
  employee_code text,
  language_code text,
  proficiency_level text,
  skill_type text,
  is_primary boolean,
  updated_at timestamptz
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_ref text := nullif(trim(coalesce(
    p_payload ->> 'employee_id_or_code',
    p_payload ->> 'employee_id',
    p_payload ->> 'employee_code'
  )), '');
  v_ref_uuid uuid;
  v_org_id uuid := nullif(p_payload ->> 'org_id', '')::uuid;
  v_company_id uuid := nullif(p_payload ->> 'company_id', '')::uuid;
  v_environment_type text := nullif(trim(coalesce(p_payload ->> 'environment_type', '')), '');
  v_actor_user_id uuid := coalesce(auth.uid(), nullif(p_payload ->> 'actor_user_id', '')::uuid);
  v_language_code text := lower(nullif(trim(coalesce(p_payload ->> 'language_code', '')), ''));
  v_proficiency_level text := nullif(trim(coalesce(p_payload ->> 'proficiency_level', '')), '');
  v_skill_type text := nullif(trim(coalesce(p_payload ->> 'skill_type', '')), '');
  v_is_primary boolean := coalesce((p_payload ->> 'is_primary')::boolean, false);

  v_employee public.employees%rowtype;
  v_candidate_count int;
  v_row public.employee_language_skills%rowtype;
begin
  if v_ref is null then
    raise exception 'EMPLOYEE_REF_REQUIRED';
  end if;
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;
  if v_language_code is null then
    raise exception 'LANGUAGE_CODE_REQUIRED';
  end if;
  if v_proficiency_level is null then
    raise exception 'PROFICIENCY_LEVEL_REQUIRED';
  end if;
  if v_skill_type is null then
    raise exception 'SKILL_TYPE_REQUIRED';
  end if;

  begin
    v_ref_uuid := v_ref::uuid;
  exception
    when others then
      v_ref_uuid := null;
  end;

  if v_ref_uuid is not null then
    select count(*)::int
      into v_candidate_count
    from public.employees e
    where e.id = v_ref_uuid
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type);

    if v_candidate_count = 0 then
      raise exception 'EMPLOYEE_NOT_FOUND';
    end if;

    select e.*
      into v_employee
    from public.employees e
    where e.id = v_ref_uuid
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type)
    limit 1;
  else
    select count(*)::int
      into v_candidate_count
    from public.employees e
    where upper(e.employee_code) = upper(v_ref)
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type);

    if v_candidate_count = 0 then
      raise exception 'EMPLOYEE_NOT_FOUND';
    elsif v_candidate_count > 1 then
      raise exception 'EMPLOYEE_CODE_AMBIGUOUS';
    end if;

    select e.*
      into v_employee
    from public.employees e
    where upper(e.employee_code) = upper(v_ref)
      and (v_org_id is null or e.org_id = v_org_id)
      and (v_company_id is null or e.company_id = v_company_id)
      and (v_environment_type is null or e.environment_type = v_environment_type)
    limit 1;
  end if;

  if v_is_primary then
    update public.employee_language_skills s
    set is_primary = false,
        updated_at = now(),
        updated_by = v_actor_user_id
    where s.employee_id = v_employee.id
      and s.environment_type = v_employee.environment_type
      and s.is_primary = true
      and not (s.language_code = v_language_code and s.skill_type = v_skill_type);
  end if;

  insert into public.employee_language_skills (
    org_id,
    company_id,
    employee_id,
    environment_type,
    is_demo,
    language_code,
    proficiency_level,
    skill_type,
    is_primary,
    created_by,
    updated_by
  )
  values (
    v_employee.org_id,
    v_employee.company_id,
    v_employee.id,
    v_employee.environment_type,
    v_employee.is_demo,
    v_language_code,
    v_proficiency_level,
    v_skill_type,
    v_is_primary,
    v_actor_user_id,
    v_actor_user_id
  )
  on conflict on constraint employee_language_skills_employee_id_language_code_skill_ty_key
  do update
    set proficiency_level = excluded.proficiency_level,
        is_primary = excluded.is_primary,
        updated_at = now(),
        updated_by = excluded.updated_by
  returning * into v_row;

  if v_is_primary then
    update public.employee_language_skills s
    set is_primary = false,
        updated_at = now(),
        updated_by = v_actor_user_id
    where s.employee_id = v_row.employee_id
      and s.environment_type = v_row.environment_type
      and s.id <> v_row.id
      and s.is_primary = true;
  end if;

  return query
  select
    s.id,
    s.employee_id,
    e.employee_code,
    s.language_code,
    s.proficiency_level,
    s.skill_type,
    s.is_primary,
    s.updated_at
  from public.employee_language_skills s
  join public.employees e on e.id = s.employee_id
  where s.id = v_row.id;
end;
$$;

drop function if exists public.delete_employee_language_skill(uuid, uuid);
create function public.delete_employee_language_skill(
  p_skill_id uuid,
  p_actor_user_id uuid
)
returns table (
  deleted boolean,
  skill_id uuid
)
language plpgsql
volatile
security invoker
set search_path = public
as $$
declare
  v_actor_user_id uuid := coalesce(auth.uid(), p_actor_user_id);
  v_row public.employee_language_skills%rowtype;
begin
  if v_actor_user_id is null then
    raise exception 'ACTOR_USER_REQUIRED';
  end if;

  if auth.uid() is not null and p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'ACTOR_USER_MISMATCH';
  end if;

  select *
    into v_row
  from public.employee_language_skills
  where id = p_skill_id;

  if not found then
    return query select false, p_skill_id;
    return;
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.user_id = v_actor_user_id
      and m.org_id = v_row.org_id
      and (m.company_id is null or m.company_id = v_row.company_id)
      and m.environment_type::text = v_row.environment_type
      and m.role::text in ('owner', 'admin')
      and m.scope_type::text in ('org', 'company', 'branch')
  ) then
    raise exception 'DELETE_PERMISSION_DENIED';
  end if;

  delete from public.employee_language_skills
  where id = p_skill_id;

  return query select true, p_skill_id;
end;
$$;

grant execute on function public.list_employee_language_skills(text) to authenticated, service_role;
grant execute on function public.upsert_employee_language_skill(jsonb) to authenticated, service_role;
grant execute on function public.delete_employee_language_skill(uuid, uuid) to authenticated, service_role;
