-- Sprint A demo seed: company + GPS settings
-- Demo scope only:
-- org_id=10000000-0000-0000-0000-000000000002
-- company_id=20000000-0000-0000-0000-000000000002
-- environment_type='demo'
-- is_demo=true

begin;

-- company_settings
insert into company_settings (
  id, org_id, company_id, environment_type, is_demo,
  company_legal_name, tax_id, address, timezone, default_locale, is_attendance_enabled,
  created_by, updated_by
) values (
  '92000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  'demo',
  true,
  'Lemma Demo Co., Ltd.',
  '53535353',
  'Xinyi Dist., Taipei City, Taiwan',
  'Asia/Taipei',
  'zh-TW',
  true,
  null,
  null
)
on conflict (org_id, company_id, environment_type) do update
set company_legal_name = excluded.company_legal_name,
    tax_id = excluded.tax_id,
    address = excluded.address,
    timezone = excluded.timezone,
    default_locale = excluded.default_locale,
    is_attendance_enabled = excluded.is_attendance_enabled,
    updated_at = now();

-- branches / locations (3)
insert into branches (
  id, org_id, company_id, name, environment_type, is_demo,
  latitude, longitude, is_attendance_enabled,
  created_by, updated_by
) values
(
  '30000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  'Taipei Demo HQ',
  'demo',
  true,
  25.0339640,
  121.5644680,
  true,
  null,
  null
),
(
  '30000000-0000-0000-0000-000000000102',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  'Taichung Demo Office',
  'demo',
  true,
  24.1477358,
  120.6736482,
  true,
  null,
  null
),
(
  '30000000-0000-0000-0000-000000000103',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  'Kaohsiung Demo Office',
  'demo',
  true,
  22.6272784,
  120.3014353,
  false,
  null,
  null
)
on conflict (id) do update
set org_id = excluded.org_id,
    company_id = excluded.company_id,
    name = excluded.name,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    is_attendance_enabled = excluded.is_attendance_enabled,
    updated_at = now();

-- attendance_boundary_settings
insert into attendance_boundary_settings (
  id, org_id, company_id, branch_id, environment_type, is_demo,
  checkin_radius_m, is_attendance_enabled,
  created_by, updated_by
) values
(
  '93000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  null,
  'demo',
  true,
  150,
  true,
  null,
  null
),
(
  '93000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000002',
  'demo',
  true,
  120,
  true,
  null,
  null
),
(
  '93000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000002',
  '20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000103',
  'demo',
  true,
  100,
  false,
  null,
  null
)
on conflict (id) do update
set org_id = excluded.org_id,
    company_id = excluded.company_id,
    branch_id = excluded.branch_id,
    environment_type = excluded.environment_type,
    is_demo = excluded.is_demo,
    checkin_radius_m = excluded.checkin_radius_m,
    is_attendance_enabled = excluded.is_attendance_enabled,
    updated_at = now();

commit;
