## Source Record

- source_repo: `Lemma-HR-runtime`
- source_path:
  - existing read source: `app/api/settings/company-profile/route.ts`
  - intended write source: `app/api/settings/company-profile/route.ts`
- deploy_target: `Railway staging`
- deploy_method: `git-linked or CLI upload`
- contract_doc_path: `docs/api-contracts/settings.company-profile.patch.v1.md`
- deployment_id: `unknown`
- schema_version:
  - read: `settings.company_profile.v1`
  - write: `settings.company_profile.update.v1`
- owner: `organization settings / company profile`
- last_verified_at: `2026-04-20`
- notes:
  - canonical read route already exists
  - this source record establishes the matching canonical write family on the same Railway route path
  - Phase 1 write contract covers company profile only and must not expand into locations or leave policy in the same round
