#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required"
  exit 1
fi

SEED_FILE="supabase/seeds/base/hr_mvp_v1_minimal_seed.sql"

if [[ ! -f "$SEED_FILE" ]]; then
  echo "Seed file not found: $SEED_FILE"
  exit 1
fi

echo "Running seed: $SEED_FILE"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SEED_FILE"
echo "Seed completed"
