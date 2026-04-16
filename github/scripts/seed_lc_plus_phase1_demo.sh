#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required"
  exit 1
fi

SEED_FILE="supabase/seeds/demo/lc_plus_phase1_demo_seed.sql"
if [[ ! -f "$SEED_FILE" ]]; then
  echo "Seed file not found: $SEED_FILE"
  exit 1
fi

echo "Running LC+ Phase 1 demo seed..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SEED_FILE"
echo "LC+ Phase 1 demo seed completed."
