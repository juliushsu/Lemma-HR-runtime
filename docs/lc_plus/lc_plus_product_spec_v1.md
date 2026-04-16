# LC+ Product Spec v1 (Draft)

## 1. Product Positioning

Module name:
- External product name: `LC+ (Legal Counsel Plus)` / `LegalOps+`
- Internal capability domain: LegalOps + Contract Vault + AI First-Response

This module is an optional add-on, not core mandatory scope.

Core layers:
1. Contract Vault
2. Dispute Workspace
3. AI Counsel First Pass

## 2. Scope Freeze (Phase 0 / Phase 1)

In scope:
- Word/PDF upload and download
- document versioning
- document classification and tagging
- governing law / jurisdiction metadata
- legal case workspace and timeline
- case-document linking
- AI first-pass internal analysis
- analysis traceability and point consumption ledger

Out of scope (this phase):
- automated legal decision
- automated outbound legal letter sending
- formal legal opinion generation
- leave/payroll/recruitment/HR expansion
- workflow engine and complex external collaboration

## 3. Roles and Access

Human roles:
- `legal_admin`
- `legal_editor`
- `legal_reviewer`
- `legal_viewer`
- `external_counsel` (reserved)

System capability role:
- `ai_legal_analyst` (non-human capability identity)

Access principles:
- legal data must not be globally exposed to HR admin by default.
- legal module scope is independent and finer-grained than HR scope.

## 4. Functional Domains

### 4.1 Contract Vault

Capabilities:
- upload Word/PDF
- download source files
- version history and current version pointer
- document type/category/tagging
- governing law and jurisdiction metadata
- counterparty metadata
- effective/expiry/auto-renewal dates
- signing status
- source module linking (HR+/PO+/SO+/ACC+)
- key clause extraction output placeholders

Supported contract examples:
- employment contract
- NDA
- procurement contract
- vendor/supply contract
- sales contract
- consulting contract
- mandate/service agreement
- collaboration agreement
- lease agreement

### 4.2 Dispute Workspace

Capabilities:
- create legal case
- link related legal documents
- timeline events
- issue/claim-defense note capture
- governing law and forum assignment
- internal case summary

Example case types:
- labor dispute
- contract breach
- procurement dispute
- payment dispute
- confidentiality breach
- IP usage dispute

### 4.3 AI Counsel First Pass

Must do:
- extract key facts from provided materials
- classify issues under governing law context
- suggest possible liability allocation directions
- propose attack/defense draft points
- enumerate missing facts/questions
- produce internal preliminary memo
- output explicit uncertainty and risk flags

Must not do:
- guarantee outcome (for example: “will definitely win”)
- impersonate formal legal opinion
- conclude without source-document basis
- skip governing law context

## 5. Canonical AI Output Contract

Fixed output envelope:

```json
{
  "schema_version": "legal.first_pass.v1",
  "data": {
    "matter_summary": "",
    "governing_law": {
      "code": "TW",
      "confidence": "high"
    },
    "issues_identified": [],
    "possible_liability_allocations": [],
    "attack_points": [],
    "defense_points": [],
    "missing_facts": [],
    "recommended_next_steps": [],
    "risk_flags": [],
    "disclaimer_level": "internal_preliminary_only"
  },
  "meta": {
    "request_id": "",
    "timestamp": ""
  },
  "error": null
}
```

## 6. Credit Model (Commercial)

Recommended pricing model:
- base monthly subscription + points
- monthly point grant + top-up
- consumption by task complexity

Point consumption tiers:
- low: summary, clause extraction, risk tags
- medium: dispute first-pass, liability comparison, negotiation draft
- high: multi-document cross analysis, full first-pass memo, multi-round strategy, cross-jurisdiction comparison

Page count is a secondary factor, not primary billing driver.

## 7. Legal Safety Guardrails

Mandatory controls:
1. clear disclaimer
2. minimum required fields for liability first-pass:
   - governing law
   - event summary
   - key contract/attachments
   - issue statement
3. refuse/degrade response when key facts are missing
4. full traceability:
   - source documents
   - model used
   - run timestamp
   - points consumed
   - output version

## 8. Cross-Module Integration

Integrates with:
- HR+: labor contracts, offboarding disputes, attendance/overtime disputes
- PO+: procurement/vendor disputes, acceptance and delivery disputes
- SO+: sales contract and payment disputes
- ACC+: penalties, damages, disputed receivables/payables

LC+ should be shipped as cross-module optional capability.

## 9. Delivery Governance

Rules (effective immediately):
- Readdy:
  - must not create or modify DB schema
  - must not create migrations
  - may only consume approved APIs/DTO/mock adapters
- Codex:
  - owns migration/seed/route/RLS/runbook work
  - executes DB-connected operations when needed
- This round:
  - document-only draft
  - no schema migration execution
  - no route implementation for LC+

## 10. Execution Sequence

1. Freeze LC+ Product Spec v1 (this document)
2. Freeze LC+ Canonical Schema Proposal v1
3. Define LC+ demo strategy (safe/demo-only data policy)
4. Start implementation (migration + API) in later round

