-- Employee language skills v1 seed (staging demo + production scopes)
-- Goal: at least 1~2 language skills per employee, with zh/en/ja/ko/vi coverage.

with target_employees as (
  select
    e.id as employee_id,
    e.org_id,
    e.company_id,
    e.environment_type,
    e.is_demo,
    e.employee_code,
    row_number() over (
      partition by e.org_id, e.company_id, e.environment_type
      order by e.employee_code
    ) as seq_no
  from public.employees e
  where
    (e.org_id = '10000000-0000-0000-0000-000000000001'::uuid
     and e.company_id = '20000000-0000-0000-0000-000000000001'::uuid
     and e.environment_type = 'production')
    or
    (e.org_id = '10000000-0000-0000-0000-000000000002'::uuid
     and e.company_id = '20000000-0000-0000-0000-000000000002'::uuid
     and e.environment_type = 'demo')
),
lang_map as (
  select
    t.*,
    case ((t.seq_no - 1) % 5)
      when 0 then 'zh'
      when 1 then 'en'
      when 2 then 'ja'
      when 3 then 'ko'
      else 'vi'
    end as primary_lang,
    case ((t.seq_no - 1) % 5)
      when 0 then 'en'
      when 1 then 'zh'
      when 2 then 'en'
      when 3 then 'en'
      else 'en'
    end as secondary_lang
  from target_employees t
),
rows_to_insert as (
  select
    gen_random_uuid() as id,
    l.org_id,
    l.company_id,
    l.employee_id,
    l.environment_type,
    l.is_demo,
    l.primary_lang as language_code,
    'native'::text as proficiency_level,
    'spoken'::text as skill_type,
    true as is_primary,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as created_by,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as updated_by
  from lang_map l

  union all

  select
    gen_random_uuid() as id,
    l.org_id,
    l.company_id,
    l.employee_id,
    l.environment_type,
    l.is_demo,
    l.secondary_lang as language_code,
    'business'::text as proficiency_level,
    'written'::text as skill_type,
    false as is_primary,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as created_by,
    '998bf90f-588f-4cd0-9539-fb3aea46fa33'::uuid as updated_by
  from lang_map l
)
insert into public.employee_language_skills (
  id,
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
select
  r.id,
  r.org_id,
  r.company_id,
  r.employee_id,
  r.environment_type,
  r.is_demo,
  r.language_code,
  r.proficiency_level,
  r.skill_type,
  r.is_primary,
  r.created_by,
  r.updated_by
from rows_to_insert r
on conflict (employee_id, language_code, skill_type, environment_type)
do update
set
  proficiency_level = excluded.proficiency_level,
  is_primary = excluded.is_primary,
  updated_at = now(),
  updated_by = excluded.updated_by;
