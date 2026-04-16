-- Employee onboarding minimal schema (staging rollout target)
-- Scope: invitation/intake/documents/consents/signatures/contract delivery/access audit
-- Principle: UI multilingual, DB canonical fields; onboarding domain separated from employees

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
create or replace function public.current_jwt_email()
returns text
language sql
stable
as $$
  select lower(nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'email', ''))
$$;

create or replace function public.onboarding_is_invitee(row_invitee_email text)
returns boolean
language sql
stable
as $$
  select
    row_invitee_email is not null
    and current_jwt_email() is not null
    and lower(row_invitee_email) = current_jwt_email()
$$;

create or replace function public.onboarding_can_hr_read(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type = row_environment_type
      and m.role::text in ('owner','admin','manager')
      and m.scope_type::text in ('org','company')
  )
$$;

create or replace function public.onboarding_can_hr_write(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type = row_environment_type
      and m.role::text in ('owner','admin','manager')
      and m.scope_type::text in ('org','company')
  )
$$;

create or replace function public.onboarding_is_owner_or_admin(
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from memberships m
    where m.user_id = auth.uid()
      and m.org_id = row_org_id
      and (m.company_id is null or m.company_id = row_company_id)
      and m.environment_type = row_environment_type
      and m.role::text in ('owner','admin')
      and m.scope_type::text in ('org','company')
  )
$$;

-- -----------------------------------------------------------------------------
-- 1) employee_onboarding_invitations
-- -----------------------------------------------------------------------------
create table if not exists public.employee_onboarding_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  invitee_name text not null,
  invitee_phone text,
  invitee_email text,
  preferred_language text not null default 'en',
  expected_start_date date,
  channel text not null check (channel in ('line','link')),
  token_hash text not null,
  token_last4 text,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  status text not null default 'pending' check (status in ('pending','opened','submitted','expired','revoked')),
  invited_by uuid references public.users(id) on delete set null,
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  unique (id, org_id, company_id, environment_type)
);

create unique index if not exists employee_onboarding_invitations_token_scope_uidx
  on public.employee_onboarding_invitations (org_id, company_id, environment_type, token_hash);
create index if not exists employee_onboarding_invitations_scope_idx
  on public.employee_onboarding_invitations (org_id, company_id, environment_type, status, expires_at);

-- -----------------------------------------------------------------------------
-- 2) employee_onboarding_intake
-- -----------------------------------------------------------------------------
create table if not exists public.employee_onboarding_intake (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  invitation_id uuid not null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  onboarding_status text not null default 'draft' check (onboarding_status in ('draft','submitted','hr_review','approved','rejected')),
  family_name_local text,
  given_name_local text,
  full_name_local text,
  family_name_latin text,
  given_name_latin text,
  full_name_latin text,
  birth_date date,
  phone text,
  email text,
  address text,
  emergency_contact_name text,
  emergency_contact_phone text,
  nationality_code text,
  identity_document_type text not null default 'national_id' check (identity_document_type in ('national_id','passport','other')),
  is_foreign_worker boolean not null default false,
  notes text,
  submitted_at timestamptz,
  approved_at timestamptz,
  approved_by uuid references public.users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,

  unique (invitation_id),
  constraint employee_onboarding_intake_invitation_scope_fkey
    foreign key (invitation_id, org_id, company_id, environment_type)
    references public.employee_onboarding_invitations(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists employee_onboarding_intake_scope_idx
  on public.employee_onboarding_intake (org_id, company_id, environment_type, onboarding_status);

-- -----------------------------------------------------------------------------
-- 3) employee_onboarding_documents
-- -----------------------------------------------------------------------------
create table if not exists public.employee_onboarding_documents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  invitation_id uuid not null,
  intake_id uuid references public.employee_onboarding_intake(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  doc_type text not null check (doc_type in (
    'profile_photo',
    'national_id_front',
    'national_id_back',
    'education_certificate',
    'passport_page',
    'work_visa',
    'employment_contract'
  )),
  storage_bucket text not null,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  file_size_bytes bigint,
  sensitivity_level text not null default 'normal' check (sensitivity_level in ('normal','high','restricted')),
  is_required boolean not null default false,
  verification_status text not null default 'pending' check (verification_status in ('pending','accepted','rejected')),
  verified_by uuid references public.users(id) on delete set null,
  verified_at timestamptz,
  rejection_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  constraint employee_onboarding_documents_invitation_scope_fkey
    foreign key (invitation_id, org_id, company_id, environment_type)
    references public.employee_onboarding_invitations(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists employee_onboarding_documents_scope_idx
  on public.employee_onboarding_documents (org_id, company_id, environment_type, doc_type, verification_status);
create index if not exists employee_onboarding_documents_invitation_idx
  on public.employee_onboarding_documents (invitation_id, intake_id);

-- -----------------------------------------------------------------------------
-- 4) employee_onboarding_consents
-- -----------------------------------------------------------------------------
create table if not exists public.employee_onboarding_consents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  invitation_id uuid not null,
  intake_id uuid references public.employee_onboarding_intake(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  consent_type text not null check (consent_type in (
    'data_accuracy_declaration',
    'privacy_consent',
    'employment_terms_acknowledgement'
  )),
  consent_version text not null,
  consent_text_snapshot text not null,
  is_checked boolean not null default false,
  checked_at timestamptz,
  ip_address inet,
  user_agent text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  constraint employee_onboarding_consents_invitation_scope_fkey
    foreign key (invitation_id, org_id, company_id, environment_type)
    references public.employee_onboarding_invitations(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists employee_onboarding_consents_scope_idx
  on public.employee_onboarding_consents (org_id, company_id, environment_type, consent_type, created_at desc);

-- -----------------------------------------------------------------------------
-- 5) employee_onboarding_signatures
-- -----------------------------------------------------------------------------
create table if not exists public.employee_onboarding_signatures (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  invitation_id uuid not null,
  intake_id uuid references public.employee_onboarding_intake(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  signature_type text not null check (signature_type in ('intake_confirmation','employment_contract')),
  signature_storage_bucket text not null,
  signature_storage_path text not null,
  signed_at timestamptz not null,
  signer_name text not null,
  signer_locale text,
  ip_address inet,
  user_agent text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  constraint employee_onboarding_signatures_invitation_scope_fkey
    foreign key (invitation_id, org_id, company_id, environment_type)
    references public.employee_onboarding_invitations(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists employee_onboarding_signatures_scope_idx
  on public.employee_onboarding_signatures (org_id, company_id, environment_type, signature_type, signed_at desc);

-- -----------------------------------------------------------------------------
-- 6) employee_contract_deliveries
-- -----------------------------------------------------------------------------
create table if not exists public.employee_contract_deliveries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  invitation_id uuid not null,
  legal_document_id uuid references public.legal_documents(id) on delete set null,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  delivery_channel text not null check (delivery_channel in ('line','link')),
  delivered_at timestamptz not null,
  opened_at timestamptz,
  signed_at timestamptz,
  status text not null default 'sent' check (status in ('sent','opened','signed','expired','revoked')),
  delivery_ref text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  constraint employee_contract_deliveries_invitation_scope_fkey
    foreign key (invitation_id, org_id, company_id, environment_type)
    references public.employee_onboarding_invitations(id, org_id, company_id, environment_type)
    on delete cascade
);

create index if not exists employee_contract_deliveries_scope_idx
  on public.employee_contract_deliveries (org_id, company_id, environment_type, status, delivered_at desc);

-- -----------------------------------------------------------------------------
-- 7) employee_data_access_logs
-- -----------------------------------------------------------------------------
create table if not exists public.employee_data_access_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  environment_type environment_type not null default 'production',
  is_demo boolean not null default false,

  viewer_user_id uuid not null references public.users(id) on delete restrict,
  viewer_role text,
  resource_type text not null check (resource_type in ('intake','document','signature','contract_delivery')),
  resource_id uuid not null,
  action text not null check (action in ('view','download','send','request','verify')),
  reason text,
  granted_basis text,
  viewed_at timestamptz not null default now(),
  request_id text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

create index if not exists employee_data_access_logs_scope_idx
  on public.employee_data_access_logs (org_id, company_id, environment_type, viewed_at desc);
create index if not exists employee_data_access_logs_resource_idx
  on public.employee_data_access_logs (resource_type, resource_id, viewed_at desc);

create or replace function public.onboarding_can_access_invitation(
  row_invitation_id uuid,
  row_org_id uuid,
  row_company_id uuid,
  row_environment_type environment_type
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.employee_onboarding_invitations i
    where i.id = row_invitation_id
      and i.org_id = row_org_id
      and i.company_id = row_company_id
      and i.environment_type = row_environment_type
      and onboarding_is_invitee(i.invitee_email)
  )
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.employee_onboarding_invitations enable row level security;
alter table public.employee_onboarding_intake enable row level security;
alter table public.employee_onboarding_documents enable row level security;
alter table public.employee_onboarding_consents enable row level security;
alter table public.employee_onboarding_signatures enable row level security;
alter table public.employee_contract_deliveries enable row level security;
alter table public.employee_data_access_logs enable row level security;

-- Invitations
drop policy if exists employee_onboarding_invitations_hr_select on public.employee_onboarding_invitations;
create policy employee_onboarding_invitations_hr_select
on public.employee_onboarding_invitations
for select
using (onboarding_can_hr_read(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_invitations_invitee_select on public.employee_onboarding_invitations;
create policy employee_onboarding_invitations_invitee_select
on public.employee_onboarding_invitations
for select
using (onboarding_is_invitee(invitee_email));

drop policy if exists employee_onboarding_invitations_hr_insert on public.employee_onboarding_invitations;
create policy employee_onboarding_invitations_hr_insert
on public.employee_onboarding_invitations
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_invitations_hr_update on public.employee_onboarding_invitations;
create policy employee_onboarding_invitations_hr_update
on public.employee_onboarding_invitations
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_invitations_invitee_update on public.employee_onboarding_invitations;
create policy employee_onboarding_invitations_invitee_update
on public.employee_onboarding_invitations
for update
using (onboarding_is_invitee(invitee_email))
with check (onboarding_is_invitee(invitee_email));

-- Intake
drop policy if exists employee_onboarding_intake_hr_select on public.employee_onboarding_intake;
create policy employee_onboarding_intake_hr_select
on public.employee_onboarding_intake
for select
using (onboarding_can_hr_read(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_intake_invitee_select on public.employee_onboarding_intake;
create policy employee_onboarding_intake_invitee_select
on public.employee_onboarding_intake
for select
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_intake_hr_insert on public.employee_onboarding_intake;
create policy employee_onboarding_intake_hr_insert
on public.employee_onboarding_intake
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_intake_invitee_insert on public.employee_onboarding_intake;
create policy employee_onboarding_intake_invitee_insert
on public.employee_onboarding_intake
for insert
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_intake_hr_update on public.employee_onboarding_intake;
create policy employee_onboarding_intake_hr_update
on public.employee_onboarding_intake
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_intake_invitee_update on public.employee_onboarding_intake;
create policy employee_onboarding_intake_invitee_update
on public.employee_onboarding_intake
for update
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type))
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

-- Documents
drop policy if exists employee_onboarding_documents_hr_select on public.employee_onboarding_documents;
create policy employee_onboarding_documents_hr_select
on public.employee_onboarding_documents
for select
using (
  onboarding_can_hr_read(org_id, company_id, environment_type)
  and (
    sensitivity_level in ('normal','high')
    or onboarding_is_owner_or_admin(org_id, company_id, environment_type)
  )
);

drop policy if exists employee_onboarding_documents_invitee_select on public.employee_onboarding_documents;
create policy employee_onboarding_documents_invitee_select
on public.employee_onboarding_documents
for select
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_documents_hr_insert on public.employee_onboarding_documents;
create policy employee_onboarding_documents_hr_insert
on public.employee_onboarding_documents
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_documents_invitee_insert on public.employee_onboarding_documents;
create policy employee_onboarding_documents_invitee_insert
on public.employee_onboarding_documents
for insert
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_documents_hr_update on public.employee_onboarding_documents;
create policy employee_onboarding_documents_hr_update
on public.employee_onboarding_documents
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

-- Consents
drop policy if exists employee_onboarding_consents_hr_select on public.employee_onboarding_consents;
create policy employee_onboarding_consents_hr_select
on public.employee_onboarding_consents
for select
using (onboarding_can_hr_read(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_consents_invitee_select on public.employee_onboarding_consents;
create policy employee_onboarding_consents_invitee_select
on public.employee_onboarding_consents
for select
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_consents_hr_insert on public.employee_onboarding_consents;
create policy employee_onboarding_consents_hr_insert
on public.employee_onboarding_consents
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_consents_invitee_insert on public.employee_onboarding_consents;
create policy employee_onboarding_consents_invitee_insert
on public.employee_onboarding_consents
for insert
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_consents_hr_update on public.employee_onboarding_consents;
create policy employee_onboarding_consents_hr_update
on public.employee_onboarding_consents
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

-- Signatures
drop policy if exists employee_onboarding_signatures_hr_select on public.employee_onboarding_signatures;
create policy employee_onboarding_signatures_hr_select
on public.employee_onboarding_signatures
for select
using (
  onboarding_can_hr_read(org_id, company_id, environment_type)
  and onboarding_is_owner_or_admin(org_id, company_id, environment_type)
);

drop policy if exists employee_onboarding_signatures_invitee_select on public.employee_onboarding_signatures;
create policy employee_onboarding_signatures_invitee_select
on public.employee_onboarding_signatures
for select
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_signatures_hr_insert on public.employee_onboarding_signatures;
create policy employee_onboarding_signatures_hr_insert
on public.employee_onboarding_signatures
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_onboarding_signatures_invitee_insert on public.employee_onboarding_signatures;
create policy employee_onboarding_signatures_invitee_insert
on public.employee_onboarding_signatures
for insert
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_onboarding_signatures_hr_update on public.employee_onboarding_signatures;
create policy employee_onboarding_signatures_hr_update
on public.employee_onboarding_signatures
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

-- Contract deliveries
drop policy if exists employee_contract_deliveries_hr_select on public.employee_contract_deliveries;
create policy employee_contract_deliveries_hr_select
on public.employee_contract_deliveries
for select
using (onboarding_can_hr_read(org_id, company_id, environment_type));

drop policy if exists employee_contract_deliveries_invitee_select on public.employee_contract_deliveries;
create policy employee_contract_deliveries_invitee_select
on public.employee_contract_deliveries
for select
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

drop policy if exists employee_contract_deliveries_hr_insert on public.employee_contract_deliveries;
create policy employee_contract_deliveries_hr_insert
on public.employee_contract_deliveries
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_contract_deliveries_hr_update on public.employee_contract_deliveries;
create policy employee_contract_deliveries_hr_update
on public.employee_contract_deliveries
for update
using (onboarding_can_hr_write(org_id, company_id, environment_type))
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

drop policy if exists employee_contract_deliveries_invitee_update on public.employee_contract_deliveries;
create policy employee_contract_deliveries_invitee_update
on public.employee_contract_deliveries
for update
using (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type))
with check (onboarding_can_access_invitation(invitation_id, org_id, company_id, environment_type));

-- Access logs (append-only for non-service roles)
drop policy if exists employee_data_access_logs_hr_select on public.employee_data_access_logs;
create policy employee_data_access_logs_hr_select
on public.employee_data_access_logs
for select
using (onboarding_can_hr_read(org_id, company_id, environment_type));

drop policy if exists employee_data_access_logs_hr_insert on public.employee_data_access_logs;
create policy employee_data_access_logs_hr_insert
on public.employee_data_access_logs
for insert
with check (onboarding_can_hr_write(org_id, company_id, environment_type));

-- no update/delete policy intentionally: deny by default under RLS
