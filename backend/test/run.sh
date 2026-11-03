#!/usr/bin/env bash
# Apply every migration to a throw-away local PostgreSQL database and run the RLS tests.
# Needs psql and a local server. Usage: PGHOST=/tmp PGPORT=5433 PGUSER=postgres bash test/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${TEST_DB:-shackleton_test}
psql -q -d postgres -c "DROP DATABASE IF EXISTS $DB" -c "CREATE DATABASE $DB"
psql -q -d "$DB" -v ON_ERROR_STOP=1 -f test/supabase_shim.sql
for m in prisma/migrations/*/migration.sql; do
  echo "apply $m"
  psql -q -d "$DB" -v ON_ERROR_STOP=1 -1 -f "$m" 2>&1 | grep -v 'already exists, skipping' || true
  psql -q -d "$DB" -tc "select 1" >/dev/null
done
psql -d "$DB" -qtA -v ON_ERROR_STOP=1 -f test/rls_test.sql 2>&1 | sed "s/^psql:[^ ]* NOTICE:  //" | grep -v "^$"
