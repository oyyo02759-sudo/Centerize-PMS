# Centerize PMS API

Multi-property management API (NestJS + PostgreSQL + Prisma). Phase 1 focuses on the **room grid matrix**, billing reads, and WebSocket grid snapshots.

## Prerequisites

- **Node.js** 20+ and **npm** 10+
- **Docker Desktop** (or Docker Engine + Compose v2) for local PostgreSQL

## One-command setup (all README steps)

```bash
chmod +x scripts/setup-and-verify.sh
npm run setup
```

Runs install → `.env` → database → Prisma generate → build → API smoke tests.

## Quick start

### 1. Install dependencies

```bash
npm install
```

Runs `prisma generate` automatically via `postinstall`.

### 2. Configure environment

```bash
cp .env.example .env
```

Default values match `docker-compose.yml` (Postgres on `localhost:5432`, database `centerize_pms`).

### 3. Start PostgreSQL

```bash
npm run db:up
```

Uses **Docker Compose** when `docker` is installed; otherwise starts **embedded Postgres** (no Docker required).

Docker-only alternative:

```bash
npm run db:up:docker
```

On first start, init scripts apply:

- `schema.sql` — DDL, enums, triggers
- `seed.sql` — demo org, properties A/B, rooms, leases, invoices

Wait until the container is healthy:

```bash
docker compose ps
```

### 4. Generate Prisma Client (if needed)

```bash
npm run prisma:generate
```

### 5. Build and run the API

```bash
npm run build
npm run start:dev
```

API listens on **http://localhost:3000** (override with `PORT` in `.env`).

### 6. Verify the stack

```bash
# Database + API health
curl -s http://localhost:3000/health | jq .

# Property list (seed: PROPERTY_A, PROPERTY_B)
curl -s http://localhost:3000/properties | jq .

# Grid matrix — Property A
curl -s http://localhost:3000/properties/b0000000-0000-4000-8000-000000000001/grid | jq .

# Overdue invoice — Property A Room 4
curl -s http://localhost:3000/billing/invoices/10000001-0000-4000-8000-000000000003 | jq .
```

Expected health response:

```json
{
  "status": "ok",
  "database": "connected",
  "propertyCount": 2
}
```

## npm scripts

| Script | Description |
|--------|-------------|
| `npm run db:up` | Start Postgres in Docker |
| `npm run db:down` | Stop Postgres |
| `npm run db:reset` | Destroy volume and re-apply schema + seed |
| `npm run db:logs` | Follow Postgres logs |
| `npm run prisma:generate` | Regenerate `@prisma/client` |
| `npm run prisma:studio` | Open Prisma Studio UI |
| `npm run start:dev` | NestJS watch mode |
| `npm run build` | Production build |
| `npm run lint` | ESLint |
| `npm run test` | Jest unit tests |

## WebSocket (grid)

- Namespace: `http://localhost:3000/grid`
- Subscribe: emit `property.subscribe` with `{ "propertyId": "<uuid>" }`
- Server replies with ack `{ "channel": "property:<id>:grid" }` and pushes `grid.snapshot`

## Seed IDs (development)

| Resource | UUID |
|----------|------|
| Organization | `a0000000-0000-4000-8000-000000000001` |
| Property A | `b0000000-0000-4000-8000-000000000001` |
| Property B | `b0000000-0000-4000-8000-000000000002` |
| Overdue invoice (Room 4) | `10000001-0000-4000-8000-000000000003` |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `database: disconnected` on `/health` | Run `npm run db:up`; check `docker compose ps` is healthy |
| Port 5432 in use | Change `DB_PORT` in `.env` and `ports` in `docker-compose.yml` |
| Empty DB after first run | Init scripts only run on empty volume — use `npm run db:reset` |
| Prisma client out of date | `npm run prisma:generate` |

## Project layout

```
schema.sql          # PostgreSQL DDL (applied by Docker init)
seed.sql            # Development seed data
prisma/schema.prisma
src/modules/property/   # GET /properties, /grid
src/modules/billing/    # GET /billing/invoices/:id
src/modules/websocket/  # Socket.io /grid
docs/api/               # API contracts
```

## API contract

See [`docs/api/PROPERTY_ROOM_GRID_API_CONTRACT.md`](docs/api/PROPERTY_ROOM_GRID_API_CONTRACT.md).
