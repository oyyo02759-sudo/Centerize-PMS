#!/usr/bin/env bash
# Runs every step in README.md (Quick start + Verify).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROPERTY_A_ID="b0000000-0000-4000-8000-000000000001"
OVERDUE_INVOICE_ID="10000001-0000-4000-8000-000000000003"
API_BASE="${API_BASE:-http://localhost:3000}"

echo "==> 1. npm install"
npm install

echo "==> 2. Configure .env"
cp -f .env.example .env

echo "==> 3. Start PostgreSQL"
mkdir -p .data
if command -v docker >/dev/null 2>&1 || [ -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
  npm run db:up
  echo "Waiting for Postgres health …"
  for _ in $(seq 1 30); do
    if docker compose ps 2>/dev/null | grep -q healthy; then
      break
    fi
    sleep 2
  done
elif [ -f .data/postgres/.schema-applied ] && nc -z localhost 5432 2>/dev/null; then
  echo "Postgres already running on :5432"
else
  echo "Docker not available — using embedded Postgres (background)"
  node scripts/start-db.mjs &
  DB_PID=$!
  echo "$DB_PID" > .data/postgres-embedded.pid
  for _ in $(seq 1 60); do
    if [ -f .data/postgres/.schema-applied ] && nc -z localhost 5432 2>/dev/null; then
      break
    fi
    sleep 2
  done
fi

echo "==> 4. prisma generate"
npm run prisma:generate

echo "==> 5. npm run build"
npm run build

echo "==> 6. Start API (background)"
npm run start:prod &
API_PID=$!
echo "$API_PID" > .data/api.pid
trap 'kill "$API_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  if curl -sf "$API_BASE/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "==> 7. Verify endpoints"
echo "--- GET /health"
curl -sf "$API_BASE/health"
echo ""
echo "--- GET /properties"
curl -sf "$API_BASE/properties"
echo ""
echo "--- GET /properties/:id/grid"
curl -sf "$API_BASE/properties/$PROPERTY_A_ID/grid" | head -c 500
echo "…"
echo ""
echo "--- GET /billing/invoices/:id"
curl -sf "$API_BASE/billing/invoices/$OVERDUE_INVOICE_ID" | head -c 400
echo "…"
echo ""

HEALTH_JSON="$(curl -sf "$API_BASE/health")"
if echo "$HEALTH_JSON" | grep -q '"database":"connected"'; then
  echo "✅ All README verification steps passed."
else
  echo "❌ Health check did not report database connected:"
  echo "$HEALTH_JSON"
  exit 1
fi
