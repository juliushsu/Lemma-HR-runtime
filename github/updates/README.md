# Versioned Update Packs

This directory is for human-friendly upload batches.

Each update pack should contain only the files changed in that specific round, arranged to mirror the target GitHub path structure.

## Naming Convention

Use:

`YYYY-MM-DD_vNN_short-topic`

Where:

- `YYYY-MM-DD` = update date
- `vNN` = same-day sequence number such as `v01`, `v02`, `v03`
- `short-topic` = short human-readable topic

Examples:

- `2026-04-14_v01_selected-context-phase2`
- `2026-04-14_v02_selected-context-phase2_docs-aligned`
- `2026-04-14_v03_github-main-path-fix`
- `2026-04-15_v01_repo-governance-followup`
- `2026-04-16_v01_seed-registry-fixes`

## How to Use

1. Open the update pack for the round you want to upload.
2. Treat the subfolders inside that pack as the real GitHub target structure.
3. Upload only the files inside that pack.

## Rule

Do not mix unrelated rounds into the same update pack.

## Current Packs

- `2026-04-14_v01_selected-context-phase2`
- `2026-04-14_v02_selected-context-phase2_docs-aligned`
- `2026-04-14_v03_github-main-path-fix`
