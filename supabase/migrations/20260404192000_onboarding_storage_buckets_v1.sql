-- Onboarding storage buckets (staging)
-- Buckets are private; upload/download should be brokered by backend using signed URLs.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'onboarding-documents',
    'onboarding-documents',
    false,
    20971520,
    array[
      'image/jpeg',
      'image/png',
      'application/pdf'
    ]::text[]
  ),
  (
    'onboarding-signatures',
    'onboarding-signatures',
    false,
    10485760,
    array[
      'image/png',
      'image/svg+xml',
      'application/octet-stream'
    ]::text[]
  ),
  (
    'employment-contracts',
    'employment-contracts',
    false,
    20971520,
    array[
      'application/pdf'
    ]::text[]
  )
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types,
  updated_at = now();

-- Explicit service-role object access for onboarding buckets.
drop policy if exists onboarding_storage_objects_service_role_all on storage.objects;
create policy onboarding_storage_objects_service_role_all
on storage.objects
for all
to service_role
using (bucket_id in ('onboarding-documents', 'onboarding-signatures', 'employment-contracts'))
with check (bucket_id in ('onboarding-documents', 'onboarding-signatures', 'employment-contracts'));

-- Service role can list bucket metadata.
drop policy if exists onboarding_storage_buckets_service_role_select on storage.buckets;
create policy onboarding_storage_buckets_service_role_select
on storage.buckets
for select
to service_role
using (id in ('onboarding-documents', 'onboarding-signatures', 'employment-contracts'));
