# Centerize PMS — Project Brief

**Document status:** Locked requirements & validated architecture  
**Version:** 1.0  
**Last updated:** 2026-05-17

---

## 1. Executive Summary & Core Objective

### Purpose

**Centerize PMS** is a **Multi-Property Management System** inspired by [LangHorPak](https://langhorpak.com) (Thai dormitory / rental-room operations). It is purpose-built for operators who manage **many properties from one control plane**, with each property having **different room counts, occupancy patterns, and spatial layouts**—without redeploying code or patching hard-coded floor plans.

### Core Objective

Deliver a single platform that:

| Capability | Outcome |
|------------|---------|
| **Unified operations** | Staff manage leases, billing, payments, and maintenance across all properties from one dashboard. |
| **Dynamic spatial UI** | Room availability and status render as a **config-driven grid matrix** per property (not fixed templates). |
| **Real-time truth** | Room grid state propagates instantly to all connected clients via WebSockets. |
| **Automated collections** | PromptPay Dynamic QR invoices reconcile automatically through payment-provider webhooks. |
| **Audit-grade history** | Every material state change on rooms, leases, invoices, payments, and maintenance is logged immutably. |

### Success Criteria (Phase 1)

- Onboard **Property A** (14 rooms) and **Property B** (8 rooms) with correct grid dimensions and live occupancy.
- Add a hypothetical **Property C** (or D) by **configuration + data only**—no layout code changes.
- End-to-end flow: vacant room → active lease → issued invoice → PromptPay QR → webhook reconciliation → paid invoice → room reflects paid/current state in the grid within seconds.

---

## 2. Property Configurations & Spatial Specifications

Properties are first-class entities. Each property owns a **spatial configuration** that drives how the frontend renders the room matrix and how the API validates room placement.

### Property A

| Attribute | Value |
|-----------|-------|
| **Total rooms** | 14 |
| **Occupied** | 10 |
| **Vacant** | 4 — **Rooms 1, 8, 10, 14** |
| **Grid layout** | **2 rows × 7 columns** (dynamic `grid_rows = 2`, `grid_columns = 7`) |
| **Room numbering** | Sequential 1–14 mapped to grid cells left-to-right, top-to-bottom (row-major) |

**Grid visualization (O = occupied, V = vacant):**

```
        Col1  Col2  Col3  Col4  Col5  Col6  Col7
Row 1    V     O     O     O     O     O     O      → Rooms 1–7
Row 2    O     V     O     V     O     O     V      → Rooms 8–14
```

### Property B

| Attribute | Value |
|-----------|-------|
| **Total rooms** | 8 |
| **Location context** | Near **Aranyaprathet District Office** (อำเภออรัญประเทศ) |
| **Grid layout** | **2 rows × 4 columns** (dynamic `grid_rows = 2`, `grid_columns = 4`) |
| **Room numbering** | Sequential 1–8, row-major in 2×4 matrix |

**Grid visualization:**

```
        Col1  Col2  Col3  Col4
Row 1    ·     ·     ·     ·      → Rooms 1–4
Row 2    ·     ·     ·     ·      → Rooms 5–8
```

> **Note:** Initial occupancy for Property B is not locked in this brief; room-level states are authoritative at runtime.

### Spatial Data Model (Conceptual)

Each **room** record must include:

- `property_id`
- `room_number` (display label, unique per property)
- `grid_row`, `grid_column` (1-based indices within property bounds)
- Operational state (see Domain State Machine — Room Lifecycle)

The grid component **never** assumes 14 or 8 rooms globally—it reads `grid_rows`, `grid_columns`, and the room list for the active property only.

---

## 3. Scalability & Future Expansion Rules

These rules are **non-negotiable** for schema design, API contracts, and frontend components.

### 3.1 Configuration-Driven Layout (100% Dynamic)

| Layer | Rule |
|-------|------|
| **Database** | `properties` stores `grid_rows`, `grid_columns`, and metadata. `rooms` stores per-cell coordinates. No property-specific tables (e.g. no `property_a_rooms`). |
| **API** | Endpoints return property config + room array; clients never infer dimensions from room count alone. |
| **Frontend** | One reusable **RoomGridMatrix** component: inputs = `{ rows, columns, rooms[] }`. Cell content = room card by `(row, col)` lookup. |
| **Prohibited** | Hard-coded `switch(propertyId)`, fixed CSS grids for 2×7 only, compile-time room arrays, or magic constants like `TOTAL_ROOMS = 14`. |

### 3.2 Unequal & Irregular Properties (Property C, D, …)

Future properties may have:

- Different row/column counts (e.g. 3×5, 1×12)
- Gaps in the matrix (disabled cells / non-room placeholders via `is_active_cell` or absent room records)
- Unequal room sizes or labels (stored as room metadata, not layout logic)

**Expansion procedure:** Create property → set `grid_rows` / `grid_columns` → bulk-create or import rooms with coordinates → grid renders immediately.

### 3.3 Multi-Tenancy & Isolation

- All queries scoped by `property_id` (and eventually `organization_id` if multi-operator).
- Real-time channels namespaced: `property:{id}:grid` (see Technical Architecture).

---

## 4. Technical Architecture Baseline

Validated stack for Phase 1 implementation:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Client (Web / Mobile)                      │
│   RoomGridMatrix ◄── WebSocket ◄── REST / GraphQL (optional)   │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│              Application Layer (NestJS recommended)              │
│  • Domain modules: Property, Room, Lease, Invoice, Payment,    │
│    Maintenance                                                     │
│  • Socket.io gateway: grid state broadcast                       │
│  • Webhook controller: Opn/Omise async reconciliation queue      │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    PostgreSQL (source of truth)                    │
│  Relational schema + audit_log + payment_webhook_events            │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│              Opn Payments / Omise Adapter (external)             │
│  PromptPay Dynamic QR • Webhooks • Idempotent settlement           │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1 PostgreSQL (Database Layer)

- **Role:** System of record for properties, rooms, tenants, leases, invoices, payments, maintenance tickets, and immutable audit entries.
- **Principles:** Normalized core entities; JSONB only for provider payloads and extensible metadata; strict foreign keys; transactional state transitions.
- **Migrations:** Versioned DDL (e.g. Flyway, Prisma Migrate, or TypeORM migrations)—no manual prod edits.

### 4.2 WebSockets — Socket.io + NestJS (Real-Time Layer)

- **Role:** Propagate **room grid matrix state** (occupancy, lifecycle flags, payment-hold indicators) to all subscribed clients for a property.
- **Events (illustrative):** `grid.snapshot`, `room.state_changed`, `lease.updated`, `invoice.status_changed`.
- **Consistency:** DB commit first, then broadcast; clients reconcile via snapshot on reconnect.
- **Auth:** JWT or session on socket handshake; subscribe only to authorized `property_id` channels.

### 4.3 Opn Payments / Omise Adapter (Payments Layer)

| Concern | Approach |
|---------|----------|
| **PromptPay Dynamic QR** | Create charge/source per invoice; QR amount and reference tied to `invoice_id`. |
| **Webhooks** | Verify signature; persist raw event; enqueue async reconciliation job. |
| **Reconciliation** | Idempotent handler maps `paid` / `failed` / `expired` to Payment + Invoice state machine; never double-apply settlement. |
| **Async processing** | Queue (Bull/BullMQ, or DB outbox) between webhook receipt and domain state updates. |

---

## 5. Domain State Machine Specification

High-level transition rules, UI expectations, and audit mandates. **Detailed transition tables and domain boundaries** are specified in [`DOMAINS_STATE_MAP.md`](./DOMAINS_STATE_MAP.md).

### 5.1 Audit Logging Mandates (Global)

Every transition below that mutates business state **must** append an `audit_log` row containing at minimum:

| Field | Requirement |
|-------|-------------|
| `entity_type` | e.g. `room`, `lease`, `invoice`, `payment`, `maintenance_ticket` |
| `entity_id` | UUID of affected record |
| `from_state` / `to_state` | Previous and new enum values |
| `actor_id` | User/system principal |
| `actor_type` | `user`, `system`, `webhook` |
| `occurred_at` | Server timestamp (UTC) |
| `metadata` | JSON: reason codes, provider refs, correlation ids |

**UI rule:** State-changing actions show confirmation for irreversible steps (e.g. terminate lease, void invoice).

---

### 5.2 Room Lifecycle

| State | Meaning | Grid / UI |
|-------|---------|-----------|
| `VACANT` | No active lease; rentable | Green / available styling |
| `RESERVED` | Hold for incoming tenant | Amber; not rentable |
| `OCCUPIED` | Active lease in force | Default occupied styling |
| `MAINTENANCE` | Blocked for work | Striped / wrench icon; not rentable |
| `OUT_OF_SERVICE` | Long-term unavailable | Grayed; admin only |

**Key transitions:** `VACANT → RESERVED → OCCUPIED` (lease activation); `OCCUPIED → VACANT` (lease end + checkout); any → `MAINTENANCE` (ticket opened); `MAINTENANCE → VACANT` (work completed).

**Real-time:** All room transitions emit `room.state_changed` on property grid channel.

---

### 5.3 Lease Lifecycle

| State | Meaning |
|-------|---------|
| `DRAFT` | Terms being edited |
| `PENDING_SIGNATURE` | Awaiting tenant acceptance |
| `ACTIVE` | Billing and occupancy authoritative |
| `NOTICE_GIVEN` | Move-out scheduled |
| `TERMINATED` | Ended; historical only |
| `CANCELLED` | Never activated |

**UI:** Active lease links from room cell to lease detail; draft hidden from tenant portal.

**Coupling:** `ACTIVE` lease requires room `OCCUPIED`; termination drives room toward `VACANT` after checkout checklist.

---

### 5.4 Invoice Lifecycle

| State | Meaning |
|-------|---------|
| `DRAFT` | Not visible to tenant |
| `ISSUED` | Due; QR may be generated |
| `PARTIALLY_PAID` | Sum of allocations < total |
| `PAID` | Fully settled |
| `OVERDUE` | Past due date, not paid |
| `VOID` | Cancelled; no collection |
| `WRITTEN_OFF` | Bad debt (admin) |

**UI:** Grid may show payment badge on room when `OVERDUE` invoice exists for active lease.

**Coupling:** `ISSUED` triggers PromptPay QR creation; `PAID` often follows Payment `SUCCEEDED`.

---

### 5.5 Payment Processing

| State | Meaning |
|-------|---------|
| `PENDING` | QR/charge created |
| `PROCESSING` | Webhook received; reconciliation in flight |
| `SUCCEEDED` | Funds confirmed |
| `FAILED` | Provider failure |
| `EXPIRED` | QR/charge timeout |
| `REFUNDED` | Reversal completed |

**Async path:** Webhook → persist event → queue → idempotent reconcile → update Payment → cascade Invoice → optional grid refresh.

**UI:** Tenant sees QR while `PENDING`; staff dashboard shows processing spinner on `PROCESSING`.

---

### 5.6 Maintenance States

| State | Meaning | Room impact |
|-------|---------|-------------|
| `REPORTED` | Ticket opened | Optional; may flag room |
| `SCHEDULED` | Work date set | Often sets room `MAINTENANCE` |
| `IN_PROGRESS` | Crew on site | Room `MAINTENANCE` |
| `COMPLETED` | Work done | Room returns per ops choice (`VACANT` or prior) |
| `CANCELLED` | No work needed | Revert room hold |

**UI:** Maintenance queue per property; grid cells show ticket priority when room in `MAINTENANCE`.

---

## 6. Related Documents

| Document | Purpose |
|----------|---------|
| [`DOMAINS_STATE_MAP.md`](./DOMAINS_STATE_MAP.md) | Full domain boundaries, state enums, transition matrix, guards, and cross-domain effects |
| *(future)* `schema/` or `migrations/` | PostgreSQL DDL derived from this brief |

---

## 7. Glossary

| Term | Definition |
|------|------------|
| **Grid matrix** | 2D layout of room cells for one property, sized by `grid_rows` × `grid_columns`. |
| **LangHorPak-style** | Dormitory-focused UX: visual room board, monthly rent, PromptPay-first collections. |
| **Dynamic QR** | Amount- and reference-specific PromptPay QR per invoice instance. |
| **Reconciliation** | Matching provider webhook payload to internal Payment/Invoice records. |

---

*This brief is the authoritative product and architecture reference until superseded by a signed change request.*
