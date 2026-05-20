# Centerize PMS — Sprint Log

**Maintained by:** Yo (Assistant PM)  
**Authority:** [`PROJECT_BRIEF.md`](../PROJECT_BRIEF.md) v1.0  
**Branch:** `cursor/pms-spec-schema-and-seed`

---

## Active milestone: Phase 1 — Dynamic grid + realtime truth

| Milestone | Target outcome | Status |
|-----------|----------------|--------|
| M1 | Locked specs + PostgreSQL DDL/seed | **Done** (`4dedd7b`) |
| M2 | NestJS API skeleton (property, billing, webhook, websocket) | **Done** (`6cf1f2a`) |
| M3 | Property Room Grid API contract (NestJS ↔ Carrick) | **Done** (`docs/api/PROPERTY_ROOM_GRID_API_CONTRACT.md`) |
| M4 | Prep: wire `PropertyService` to PostgreSQL | **Pending** |
| M5 | Carrick: `RoomGridMatrix` against contract | **Unblocked** (contract ready) |
| M6 | Phase 1 E2E (vacant → lease → invoice → QR → paid grid) | **Blocked** on M4 + payments |

---

## Sprint board (2026-05-20)

| ID | Task | Owner | Status | Notes |
|----|------|-------|--------|-------|
| S-01 | Specs + schema + seed | Prep | Done | `schema.sql`, `seed.sql` |
| S-02 | NestJS scaffold committed | Prep | Done | `6cf1f2a` — see commit note below |
| S-03 | Agent definitions in repo | Choely | Done | `centerize_pms_agents/` |
| S-04 | Sprint log initialized | Yo | Done | This file |
| S-05 | Room Grid API contract published | Yo + Prep + Carrick | Done | `docs/api/PROPERTY_ROOM_GRID_API_CONTRACT.md` |
| S-06 | Implement grid REST + TypeORM entities | Prep | Pending | Skeleton returns empty/stub |
| S-07 | Frontend `RoomGridMatrix` | Carrick | Ready to start | Consumes contract v1.0 |
| S-08 | Webhook reconciliation E2E | Prep + Arm | Pending | Module stub only |

---

## Blockers

| ID | Blocker | Owner | Resolution |
|----|---------|-------|------------|
| B-01 | ~~Uncommitted `src/` / agents~~ | Prep | **Cleared** — committed in `6cf1f2a` |
| B-02 | ~~No API contract for grid~~ | Yo | **Cleared** — contract v1.0 published |
| B-03 | `PropertyService` not DB-backed | Prep | Implement per contract §8 |
| B-04 | No frontend app repo/folder | Carrick | Scaffold Next.js app; use contract base URL |
| B-05 | Payment E2E unverified | Prep + Arm | After M4 |

---

## Commit log (sprint-relevant)

| SHA | Date | Summary |
|-----|------|---------|
| `4dedd7b` | 2026-05-17 | PMS specs, PostgreSQL schema, seed data |
| `6cf1f2a` | 2026-05-20 | NestJS skeleton + agent definitions (message: `feat: scaffold NestJS project with basic schema and seed`) |
| `c23fd08` | 2026-05-20 | Sprint log + Property Room Grid API contract v1.0 |

---

## Dependency chain

```
schema.sql + seed.sql
    → PropertyService (DB)     [S-06 / B-03]
    → GET /properties/:id/grid [contract]
    → Carrick RoomGridMatrix   [S-07]
    → Socket.io grid events    [S-06 + gateway]
```

---

## Next actions (ownership)

- **Prep:** Implement contract §8 (entities, `getGridMatrix`, snapshot emit on connect).
- **Carrick:** Bootstrap dashboard; implement `RoomGridMatrix` from contract §5–6.
- **Arm:** Define grid + websocket test cases from contract §9.
- **Choely:** Confirm whether to amend `6cf1f2a` message to requested: `Feat: Complete NestJS skeleton scaffolding and internal agent setup`.

---

*Append new rows at the top of **Sprint board** each sync. Do not delete historical milestone rows.*
