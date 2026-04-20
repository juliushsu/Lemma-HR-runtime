# Docs Entry

Purpose:

- provide one document entrypoint for all AI collaborators
- reduce document drift across Readdy, Codex, and GPT
- establish the required reading order before UI or API work

This file is the primary docs entrypoint.

## Core Decision Docs

These are required reading before feature work.

1. [`architecture/leave-family-convergence-decision.v1.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/leave-family-convergence-decision.v1.md)
   Highest priority for leave-family work.
2. [`architecture/lemma-runtime-layering-v1.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/lemma-runtime-layering-v1.md)
   Required for runtime ownership, layering, and route-family interpretation.
3. [`architecture/data-truth-debugging.v1.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/architecture/data-truth-debugging.v1.md)
   Required for truth-source debugging and evidence-based reasoning.

## API Governance

Use these documents before changing or consuming APIs.

- [`api-contracts/api-source-governance.v1.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/api-source-governance.v1.md)
- [`api-contracts/source-records/`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/api-contracts/source-records)

## UI Specs

Read relevant UI specs before frontend implementation.

- [`ui-specs/hr-employee-detail-null-policy.v1.md`](/Users/chishenhsu/Desktop/Codex/Lemma%20HR+/docs/ui-specs/hr-employee-detail-null-policy.v1.md)

## Rules

These rules are mandatory.

- All AI collaborators must use GitHub `docs/` as the only source of truth.
- Sandbox or local-only docs must not be used as the final authority.
- Before frontend development, every AI must read:
  - `leave-family-convergence-decision.v1.md`
  - `lemma-runtime-layering-v1.md`

## How To Use

For Readdy:

「任何功能開發前，先讀 convergence decision，再決定 UI 與 API 使用方式」
