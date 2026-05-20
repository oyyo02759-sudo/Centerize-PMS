# Property Room Grid API Contract

**Document status:** Official interface contract (Phase 1)  
**Version:** 1.0  
**Consumers:** Carrick (Frontend) · Prep (NestJS backend)  
**Authority:** [`PROJECT_BRIEF.md`](../../PROJECT_BRIEF.md), [`DOMAINS_STATE_MAP.md`](../../DOMAINS_STATE_MAP.md)  
**Implementation reference:** `src/modules/property/property.controller.ts`, `src/modules/websocket/grid.gateway.ts`  
**Last updated:** 2026-05-20

---

## 1. Purpose

Defines the **REST** and **WebSocket** interface for the **config-driven room grid matrix** (`RoomGridMatrix`). Carrick may implement against this contract while Prep wires PostgreSQL; field names and enums are stable for v1.0.

---

## 2. Conventions

| Rule | Value |
|------|-------|
| Base URL (dev) | `http://localhost:3000` |
| JSON casing | **camelCase** in all API bodies |
| IDs | UUID v4 strings |
| Timestamps | ISO 8601 UTC (`2026-05-20T12:00:00.000Z`) |
| Auth (Phase 1) | **None** on grid read paths (dev only); production will require JWT — see §10 |
| Errors | NestJS default JSON: `{ "statusCode": number, "message": string \| string[], "error": string }` |

---

## 3. Domain enums (from PostgreSQL / `DOMAINS_STATE_MAP.md`)

### 3.1 `RoomStatus`

```
VACANT | RESERVED | OCCUPIED | MAINTENANCE | OUT_OF_SERVICE
```

### 3.2 `GridBillingBadge` (derived, not a DB column)

| Value | When |
|-------|------|
| `NONE` | No `ISSUED` / `OVERDUE` invoice on active lease for room |
| `OVERDUE` | At least one `OVERDUE` invoice linked to room's active lease |
| `DUE` | `ISSUED` invoice, not past due (optional Phase 1) |

---

## 4. REST — Property list & detail

### 4.1 `GET /properties`

Returns all non-deleted properties for the operator context (Phase 1: single org from seed).

**Response `200`:** `PropertySummary[]`

```json
[
  {
    "id": "b0000000-0000-4000-8000-000000000001",
    "code": "PROPERTY_A",
    "name": "Property A",
    "gridRows": 2,
    "gridColumns": 7,
    "locationNotes": null
  }
]
```

| Field | Type | Required | Source column |
|-------|------|----------|---------------|
| `id` | uuid | yes | `properties.id` |
| `code` | string | yes | `properties.code` |
| `name` | string | yes | `properties.name` |
| `gridRows` | integer ≥ 1 | yes | `properties.grid_rows` |
| `gridColumns` | integer ≥ 1 | yes | `properties.grid_columns` |
| `locationNotes` | string \| null | yes | `properties.location_notes` |

---

### 4.2 `GET /properties/:id`

**Params:** `id` — UUID  

**Response `200`:** `PropertyDetail`

```json
{
  "id": "b0000000-0000-4000-8000-000000000001",
  "organizationId": "a0000000-0000-4000-8000-000000000001",
  "code": "PROPERTY_A",
  "name": "Property A",
  "address": "Bangkok Metropolitan Demo Site",
  "locationNotes": null,
  "gridRows": 2,
  "gridColumns": 7,
  "metadata": { "phase": 1, "prototype": true },
  "createdAt": "2026-05-17T00:00:00.000Z",
  "updatedAt": "2026-05-17T00:00:00.000Z"
}
```

**Response `404`:** Property not found or soft-deleted.

---

## 5. REST — Grid matrix (primary Carrick endpoint)

### 5.1 `GET /properties/:id/grid`

**Purpose:** Single payload to render `RoomGridMatrix`: dimensions + all room cells.

**Params:** `id` — UUID  

**Response `200`:** `PropertyGridMatrix`

```json
{
  "propertyId": "b0000000-0000-4000-8000-000000000001",
  "code": "PROPERTY_A",
  "name": "Property A",
  "gridRows": 2,
  "gridColumns": 7,
  "rooms": [
    {
      "id": "c1a00000-0000-4000-8000-000000000001",
      "roomNumber": "1",
      "gridPositionRow": 1,
      "gridPositionCol": 1,
      "status": "VACANT",
      "isActiveCell": true,
      "label": "Room 1",
      "activeLeaseId": null,
      "tenantDisplayName": null,
      "billingBadge": "NONE",
      "metadata": {}
    },
    {
      "id": "c1a00000-0000-4000-8000-000000000004",
      "roomNumber": "4",
      "gridPositionRow": 1,
      "gridPositionCol": 4,
      "status": "OCCUPIED",
      "isActiveCell": true,
      "label": "Room 4",
      "activeLeaseId": "e1a00000-0000-4000-8000-000000000004",
      "tenantDisplayName": "Kittisak Boonma",
      "billingBadge": "OVERDUE",
      "metadata": {}
    }
  ],
  "generatedAt": "2026-05-20T10:00:00.000Z"
}
```

### 5.2 `PropertyGridMatrix` fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `propertyId` | uuid | yes | Same as `:id` |
| `code` | string | yes | For property switcher labels |
| `name` | string | yes | Display title |
| `gridRows` | integer | yes | Matrix height |
| `gridColumns` | integer | yes | Matrix width |
| `rooms` | `GridRoomCell[]` | yes | May be empty array; length ≤ rows×cols |
| `generatedAt` | ISO datetime | yes | Server snapshot time |

### 5.3 `GridRoomCell` fields

| Field | Type | Required | DB / logic |
|-------|------|----------|------------|
| `id` | uuid | yes | `rooms.id` |
| `roomNumber` | string | yes | `rooms.room_number` |
| `gridPositionRow` | integer ≥ 1 | yes | `rooms.grid_position_row` |
| `gridPositionCol` | integer ≥ 1 | yes | `rooms.grid_position_col` |
| `status` | `RoomStatus` | yes | `rooms.status` |
| `isActiveCell` | boolean | yes | `rooms.is_active_cell` — if `false`, render disabled placeholder |
| `label` | string \| null | yes | `rooms.label` |
| `activeLeaseId` | uuid \| null | yes | `leases.id` where `status IN ('ACTIVE','NOTICE_GIVEN')` for room |
| `tenantDisplayName` | string \| null | yes | Primary tenant on active lease; null if no lease |
| `billingBadge` | `GridBillingBadge` | yes | Derived from invoices on active lease |
| `metadata` | object | yes | `rooms.metadata` |

### 5.4 Frontend rendering rules (Carrick)

1. **Matrix size** comes only from `gridRows` × `gridColumns` — never from `rooms.length`.
2. **Cell lookup:** `rooms.find(r => r.gridPositionRow === row && r.gridPositionCol === col)`.
3. **Missing cell:** If no room at `(row, col)`, render empty/inactive slot (future `is_active_cell` gaps).
4. **Row-major numbering** matches seed: Property A room `1` = (1,1), room `8` = (2,1).
5. **Styling map** per `DOMAINS_STATE_MAP.md` §5.3:

| `status` | UI |
|----------|-----|
| `VACANT` | Available (green) |
| `RESERVED` | Hold (amber) |
| `OCCUPIED` | Default occupied |
| `MAINTENANCE` | Wrench overlay |
| `OUT_OF_SERVICE` | Disabled gray |

6. **`billingBadge === 'OVERDUE'`** — show payment alert badge on cell (seed: Property A room `4`, Property B room `5`).

### 5.5 Errors

| Code | Condition |
|------|-----------|
| `400` | Invalid UUID in `:id` |
| `404` | Unknown `propertyId` |

---

## 6. WebSocket — Real-time grid channel

### 6.1 Connection

| Setting | Value |
|---------|-------|
| URL (dev) | `ws://localhost:3000/grid` |
| Namespace | `/grid` (Socket.io path `/socket.io`) |
| Library | Socket.io client v4 |

### 6.2 Client → server

**Event:** `property.subscribe`

```json
{ "propertyId": "b0000000-0000-4000-8000-000000000001" }
```

**Ack response:**

```json
{ "channel": "property:b0000000-0000-4000-8000-000000000001:grid" }
```

Client joins internal room `property:{propertyId}:grid`.

### 6.3 Server → client events

#### `grid.snapshot`

Full room list refresh after subscribe or reconnect.

```json
{
  "propertyId": "b0000000-0000-4000-8000-000000000001",
  "rooms": [ /* GridRoomCell[] — same shape as REST, minus property wrapper */ ]
}
```

**Carrick rule:** On `grid.snapshot`, merge into local grid state by `room.id`.

#### `room.state_changed`

Incremental cell update.

```json
{
  "propertyId": "b0000000-0000-4000-8000-000000000001",
  "roomId": "c1a00000-0000-4000-8000-000000000001",
  "from": "VACANT",
  "to": "RESERVED"
}
```

**Carrick rule:** Patch `status` for matching `roomId`; optionally refetch `GET /properties/:id/grid` if `billingBadge` may change.

#### Phase 1 optional (documented, not required for Carrick MVP)

| Event | Payload |
|-------|---------|
| `invoice.status_changed` | `{ invoiceId, status, roomId? }` |
| `lease.updated` | `{ leaseId, status }` |

### 6.4 Recommended client flow

```
1. GET /properties/:id/grid     → initial render
2. connect /grid namespace
3. emit property.subscribe
4. on grid.snapshot             → reconcile state
5. on room.state_changed        → patch or refetch
```

---

## 7. Seed reference IDs (dev / QA)

| Property | UUID | Grid | Vacant rooms (seed) |
|----------|------|------|---------------------|
| Property A | `b0000000-0000-4000-8000-000000000001` | 2×7 | 1, 8, 10, 14 |
| Property B | `b0000000-0000-4000-8000-000000000002` | 2×4 | none (all occupied) |

**Overdue badge test rooms:**

| Property | Room # | Room UUID |
|----------|--------|-----------|
| A | 4 | `c1a00000-0000-4000-8000-000000000004` |
| B | 5 | `c1b00000-0000-4000-8000-000000000005` |

---

## 8. Backend implementation checklist (Prep)

- [ ] TypeORM entities: `Property`, `Room`, `Lease`, `Tenant`, `Invoice` (read-only joins for grid)
- [ ] `PropertyService.getGridMatrix()` — SQL or query builder matching §5
- [ ] Map DB snake_case → API camelCase
- [ ] On room status transition: `GridGateway.emitRoomStateChanged()`
- [ ] On subscribe: `GridGateway.emitGridSnapshot()` with full `GridRoomCell[]`
- [ ] Filter `deleted_at IS NULL` on properties and rooms

---

## 9. Acceptance criteria (Arm / Carrick)

| # | Test |
|---|------|
| AC-1 | `GET /properties` returns 2 properties with correct `gridRows`/`gridColumns` |
| AC-2 | `GET /properties/{propertyA}/grid` returns 14 rooms with correct coordinates |
| AC-3 | Property A rooms 1,8,10,14 have `status: VACANT` |
| AC-4 | Property A room 4 has `billingBadge: OVERDUE` |
| AC-5 | WebSocket subscribe receives `grid.snapshot` with 14 rooms |
| AC-6 | Simulated `room.state_changed` updates one cell without full page reload |

---

## 10. Versioning & auth (future)

| Version | Change |
|---------|--------|
| v1.0 | Current document; dev open read |
| v1.1 | JWT on REST + socket handshake; `organizationId` scoping |

Breaking changes require contract version bump and Carrick sync.

---

## 11. TypeScript types (Carrick copy-paste)

```typescript
export type RoomStatus =
  | 'VACANT'
  | 'RESERVED'
  | 'OCCUPIED'
  | 'MAINTENANCE'
  | 'OUT_OF_SERVICE';

export type GridBillingBadge = 'NONE' | 'DUE' | 'OVERDUE';

export interface GridRoomCell {
  id: string;
  roomNumber: string;
  gridPositionRow: number;
  gridPositionCol: number;
  status: RoomStatus;
  isActiveCell: boolean;
  label: string | null;
  activeLeaseId: string | null;
  tenantDisplayName: string | null;
  billingBadge: GridBillingBadge;
  metadata: Record<string, unknown>;
}

export interface PropertyGridMatrix {
  propertyId: string;
  code: string;
  name: string;
  gridRows: number;
  gridColumns: number;
  rooms: GridRoomCell[];
  generatedAt: string;
}

export interface PropertySummary {
  id: string;
  code: string;
  name: string;
  gridRows: number;
  gridColumns: number;
  locationNotes: string | null;
}
```

---

*Contract v1.0 unblocks Carrick `RoomGridMatrix` implementation. Prep implements §8 against the same shapes.*
