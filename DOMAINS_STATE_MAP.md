# Centerize PMS — Domain State Mapping Specification

**Document status:** Locked logical boundaries & state machines  
**Version:** 1.0  
**Companion:** [`PROJECT_BRIEF.md`](./PROJECT_BRIEF.md)  
**Last updated:** 2026-05-17

---

## 1. Purpose

This document defines **domain boundaries**, **state enumerations**, **allowed transitions**, **guards**, **UI impacts**, **audit requirements**, and **cross-domain side effects** for Centerize PMS. It is the logical contract **before** PostgreSQL DDL: every `status` column and check constraint should trace to a row in this spec.

---

## 2. Domain Map Overview

```
                    ┌──────────────┐
                    │   Property   │  (config: grid_rows, grid_columns)
                    └──────┬───────┘
                           │ 1:N
                    ┌──────▼───────┐
         ┌──────────│     Room      │◄────────────────────────────┐
         │          └──────┬───────┘                             │
         │                 │ 1:1 active (optional)              │
         │          ┌──────▼───────┐                             │
         │          │    Lease     │                             │
         │          └──────┬───────┘                             │
         │                 │ 1:N                                │
         │          ┌──────▼───────┐      ┌──────────────┐      │
         │          │   Invoice    │◄────►│   Payment    │      │
         │          └──────────────┘      └──────┬───────┘      │
         │                                       │ webhook      │
         │          ┌──────────────┐             ▼              │
         └──────────│ Maintenance  │──────► (room hold) ────────┘
                    │   Ticket     │
                    └──────────────┘
```

### 2.1 Bounded Contexts

| Domain | Aggregate Root | Owns | Does Not Own |
|--------|----------------|------|--------------|
| **Property** | `Property` | Grid dimensions, address, branding | Room operational state |
| **Room** | `Room` | Spatial coordinates, room lifecycle state | Lease legal terms, payment amounts |
| **Lease** | `Lease` | Contract lifecycle, tenant link, dates | Invoice line math (references only) |
| **Invoice** | `Invoice` | Billing lifecycle, line items, due dates | Provider charge IDs (Payment owns) |
| **Payment** | `Payment` | Provider refs, settlement state, allocations | Lease terms |
| **Maintenance** | `MaintenanceTicket` | Work order lifecycle | Permanent room removal |

### 2.2 Shared Kernel

| Concern | Owner | Consumers |
|---------|-------|-----------|
| `audit_log` | Infrastructure module | All domains on state change |
| `ActorContext` | Auth | All write operations |
| Real-time `GridBroadcast` | Room + Infrastructure | Socket.io subscribers |
| `Money` (amount, currency) | Invoice/Payment | Invoice, Payment |

---

## 3. Global Conventions

### 3.1 Transition Notation

`FROM → TO` with **Guard** `[G]` and **Side effect** `{E}`.

### 3.2 Audit Log (Required Fields)

On every **bold** transition below:

```text
audit_log (
  id, organization_id?, property_id?,
  entity_type, entity_id,
  action,              -- e.g. 'state.transition'
  from_state, to_state,
  actor_id, actor_type,  -- user | system | webhook
  correlation_id?,      -- payment webhook, request id
  metadata JSONB,
  occurred_at TIMESTAMPTZ
)
```

### 3.3 Idempotency

- Payment webhook handlers keyed by `provider_event_id` (unique).
- Replayed webhooks must not duplicate `SUCCEEDED` transitions or invoice allocations.

### 3.4 Real-Time Events

| Event | Payload (minimal) | When |
|-------|-------------------|------|
| `room.state_changed` | `roomId`, `from`, `to`, `propertyId` | Room lifecycle change |
| `grid.snapshot` | `propertyId`, `rooms[]` | Reconnect / bulk refresh |
| `lease.updated` | `leaseId`, `status` | Lease lifecycle change |
| `invoice.status_changed` | `invoiceId`, `status`, `roomId?` | Invoice transition |
| `payment.updated` | `paymentId`, `status`, `invoiceId` | Payment transition |

---

## 4. Property Domain

**Not a state machine** — configuration entity. Included for boundary clarity.

| Field | Type | Notes |
|-------|------|-------|
| `grid_rows` | int ≥ 1 | Drives matrix height |
| `grid_columns` | int ≥ 1 | Drives matrix width |
| `code` | string | e.g. `PROPERTY_A`, `PROPERTY_B` |
| `name` | string | Display name |
| `address` | text | Property B: near Aranyaprathet District Office |

**Invariant:** `COUNT(rooms WHERE property_id = X) ≤ grid_rows * grid_columns` (unless inactive cells allowed).

**UI:** Property switcher in header; selecting property loads grid config + rooms.

---

## 5. Room Lifecycle Domain

### 5.1 States

| Enum | Code | Description |
|------|------|-------------|
| Vacant | `VACANT` | Rentable, no active lease |
| Reserved | `RESERVED` | Soft hold |
| Occupied | `OCCUPIED` | Active lease |
| Maintenance | `MAINTENANCE` | Blocked for work |
| Out of Service | `OUT_OF_SERVICE` | Admin-disabled long term |

### 5.2 Transition Matrix

| From | To | Trigger | Guard `[G]` | Side Effects `{E}` |
|------|-----|---------|-------------|-------------------|
| `VACANT` | `RESERVED` | Staff reserves room | No conflicting `ACTIVE` lease | **Audit**; emit `room.state_changed` |
| `RESERVED` | `VACANT` | Hold released / expired | — | **Audit**; emit |
| `RESERVED` | `OCCUPIED` | Lease activated | Lease → `ACTIVE` | **Audit**; emit |
| `VACANT` | `OCCUPIED` | Direct move-in (skip reserve) | Lease → `ACTIVE` | **Audit**; emit |
| `OCCUPIED` | `VACANT` | Lease terminated + checkout complete | No open `ISSUED`/`OVERDUE` invoices* | **Audit**; emit |
| `*` | `MAINTENANCE` | Maintenance scheduled / in progress | Ticket exists | **Audit**; emit; badge on grid |
| `MAINTENANCE` | `VACANT` | Work completed, unit ready | Ticket → `COMPLETED` | **Audit**; emit |
| `MAINTENANCE` | `OCCUPIED` | Work completed, tenant remains | Was occupied before maintenance | **Audit**; emit |
| `*` | `OUT_OF_SERVICE` | Admin disables unit | Admin role | **Audit**; emit |
| `OUT_OF_SERVICE` | `VACANT` | Admin re-enables | Admin role | **Audit**; emit |

\* *Configurable business rule: block checkout if overdue invoices exist.*

### 5.3 UI Impact

| State | Grid Cell | Actions |
|-------|-----------|---------|
| `VACANT` | Available (green) | Create lease, reserve |
| `RESERVED` | Hold (amber) | Confirm lease, release |
| `OCCUPIED` | Occupied (default) | View lease, create invoice |
| `MAINTENANCE` | Wrench overlay | View ticket |
| `OUT_OF_SERVICE` | Disabled gray | Admin only |

### 5.4 Initial Seed Data (Property A)

Rooms **1, 8, 10, 14** → `VACANT`; all others → `OCCUPIED` (until lease records exist in DB, seed matches brief).

---

## 6. Lease Lifecycle Domain

### 6.1 States

| Enum | Code | Description |
|------|------|-------------|
| Draft | `DRAFT` | Editable, not binding |
| Pending Signature | `PENDING_SIGNATURE` | Awaiting tenant |
| Active | `ACTIVE` | Occupancy + billing authority |
| Notice Given | `NOTICE_GIVEN` | Move-out window |
| Terminated | `TERMINATED` | Historical |
| Cancelled | `CANCELLED` | Never effective |

### 6.2 Transition Matrix

| From | To | Trigger | Guard `[G]` | Side Effects `{E}` |
|------|-----|---------|-------------|-------------------|
| `DRAFT` | `PENDING_SIGNATURE` | Send for signing | Required fields complete | **Audit** |
| `DRAFT` | `CANCELLED` | Discard | — | **Audit** |
| `PENDING_SIGNATURE` | `ACTIVE` | Tenant signs / staff confirms | Room `VACANT` or `RESERVED` | Room → `OCCUPIED`; **Audit**; `lease.updated` |
| `PENDING_SIGNATURE` | `CANCELLED` | Rejected / timeout | — | Room → `VACANT` if was `RESERVED`; **Audit** |
| `ACTIVE` | `NOTICE_GIVEN` | Notice recorded | — | **Audit**; `lease.updated` |
| `ACTIVE` | `TERMINATED` | Checkout complete | Checkout checklist | Room → `VACANT`; **Audit** |
| `NOTICE_GIVEN` | `TERMINATED` | Move-out date reached | Same as above | Room → `VACANT`; **Audit** |
| `ACTIVE` | `TERMINATED` | Early termination | Admin approval if required | Room → `VACANT`; **Audit** |

### 6.3 UI Impact

| State | Staff UI | Tenant Portal |
|-------|----------|---------------|
| `DRAFT` | Full edit | Hidden |
| `PENDING_SIGNATURE` | Awaiting badge | Sign / accept |
| `ACTIVE` | Linked from room | View lease, pay invoices |
| `NOTICE_GIVEN` | Countdown to move-out | Notice banner |
| `TERMINATED` | Read-only archive | Read-only |
| `CANCELLED` | Read-only | N/A |

### 6.4 Invariants

- At most **one** `ACTIVE` or `NOTICE_GIVEN` lease per room.
- `ACTIVE` implies room `OCCUPIED` (eventual consistency within same transaction preferred).

---

## 7. Invoice Lifecycle Domain

### 7.1 States

| Enum | Code | Description |
|------|------|-------------|
| Draft | `DRAFT` | Internal only |
| Issued | `ISSUED` | Payable |
| Partially Paid | `PARTIALLY_PAID` | Allocations < total |
| Paid | `PAID` | Fully allocated |
| Overdue | `OVERDUE` | Past `due_date`, not settled |
| Void | `VOID` | Invalidated |
| Written Off | `WRITTEN_OFF` | Uncollectable |

### 7.2 Transition Matrix

| From | To | Trigger | Guard `[G]` | Side Effects `{E}` |
|------|-----|---------|-------------|-------------------|
| `DRAFT` | `ISSUED` | Issue invoice | Active lease (if rent invoice) | Create Payment `PENDING` + QR optional; **Audit**; `invoice.status_changed` |
| `DRAFT` | `VOID` | Discard draft | — | **Audit** |
| `ISSUED` | `OVERDUE` | Scheduler: `now > due_date` | Not fully paid | **Audit**; grid overdue badge |
| `ISSUED` | `PARTIALLY_PAID` | Partial allocation | `0 < paid < total` | **Audit** |
| `ISSUED` | `PAID` | Full payment | `paid = total` | **Audit**; clear overdue badge |
| `OVERDUE` | `PARTIALLY_PAID` | Partial payment | — | **Audit** |
| `OVERDUE` | `PAID` | Full payment | — | **Audit** |
| `PARTIALLY_PAID` | `PAID` | Remaining allocated | — | **Audit** |
| `ISSUED` / `OVERDUE` / `PARTIALLY_PAID` | `VOID` | Staff voids | No `SUCCEEDED` payment or refund first | **Audit**; expire Payment if `PENDING` |
| `OVERDUE` | `WRITTEN_OFF` | Admin write-off | Admin role | **Audit** |

### 7.3 UI Impact

| State | Staff | Tenant | Grid |
|-------|-------|--------|------|
| `DRAFT` | Edit lines | — | — |
| `ISSUED` | Show QR actions | Pay via QR | — |
| `PARTIALLY_PAID` | Balance due | Pay remainder | Warning |
| `PAID` | Receipt | Receipt | — |
| `OVERDUE` | Collections queue | Urgent pay | Red badge on room |
| `VOID` | Strikethrough | — | — |
| `WRITTEN_OFF` | Finance report | — | — |

### 7.4 Scheduled Jobs

| Job | Transition |
|-----|------------|
| `invoice_overdue_scan` | `ISSUED` → `OVERDUE` when `due_date < today` and not `PAID` |

---

## 8. Payment Processing Domain

### 8.1 States

| Enum | Code | Description |
|------|------|-------------|
| Pending | `PENDING` | QR/charge created, awaiting payer |
| Processing | `PROCESSING` | Webhook received, worker running |
| Succeeded | `SUCCEEDED` | Confirmed paid |
| Failed | `FAILED` | Provider declined |
| Expired | `EXPIRED` | Timeout |
| Refunded | `REFUNDED` | Money returned |

### 8.2 Transition Matrix

| From | To | Trigger | Guard `[G]` | Side Effects `{E}` |
|------|-----|---------|-------------|-------------------|
| — | `PENDING` | Invoice issued / manual charge | Invoice `ISSUED` or `OVERDUE` | Store `provider_charge_id`, QR payload; **Audit** |
| `PENDING` | `PROCESSING` | Webhook `charge.complete` (etc.) | Valid signature | **Audit**; `payment.updated` |
| `PROCESSING` | `SUCCEEDED` | Reconciliation OK | Idempotent event id | Allocate to Invoice; Invoice → `PAID` or `PARTIALLY_PAID`; **Audit**; grid refresh |
| `PROCESSING` | `FAILED` | Provider failure | — | **Audit** |
| `PENDING` | `EXPIRED` | TTL job | — | **Audit** |
| `SUCCEEDED` | `REFUNDED` | Refund API + webhook | Admin / policy | Reverse allocations; Invoice may regress; **Audit** |
| `PENDING` | `FAILED` | Create charge error | — | **Audit** |

### 8.3 Webhook Async Pipeline

```text
HTTP POST /webhooks/opn
  → verify signature
  → INSERT payment_webhook_events (status=RECEIVED)
  → enqueue ReconcilePaymentJob(event_id)
  → 202 Accepted

Worker:
  → load event (idempotent skip if PROCESSED)
  → Payment: PENDING|PROCESSING → PROCESSING → SUCCEEDED|FAILED
  → apply invoice_allocation rows
  → transition Invoice per §7
  → mark event PROCESSED
  → emit payment.updated + room grid if needed
```

### 8.4 UI Impact

| State | Staff | Tenant |
|-------|-------|--------|
| `PENDING` | Copy QR link | Display QR |
| `PROCESSING` | Spinner “Confirming…” | “Processing payment” |
| `SUCCEEDED` | Receipt link | Success |
| `FAILED` | Retry / new QR | Error + retry |
| `EXPIRED` | Regenerate QR | New QR |
| `REFUNDED` | Refund record | Notification |

---

## 9. Maintenance Domain

### 9.1 States

| Enum | Code | Description |
|------|------|-------------|
| Reported | `REPORTED` | New ticket |
| Scheduled | `SCHEDULED` | Date assigned |
| In Progress | `IN_PROGRESS` | Work underway |
| Completed | `COMPLETED` | Resolved |
| Cancelled | `CANCELLED` | No action needed |

### 9.2 Transition Matrix

| From | To | Trigger | Guard `[G]` | Side Effects `{E}` |
|------|-----|---------|-------------|-------------------|
| — | `REPORTED` | Create ticket | `room_id` optional | **Audit** |
| `REPORTED` | `SCHEDULED` | Assign date/crew | — | Room → `MAINTENANCE` (recommended); **Audit** |
| `REPORTED` | `CANCELLED` | False alarm | — | **Audit** |
| `SCHEDULED` | `IN_PROGRESS` | Crew starts | — | Room → `MAINTENANCE`; **Audit** |
| `IN_PROGRESS` | `COMPLETED` | Work done | — | Room → `VACANT` or restore prior; **Audit** |
| `SCHEDULED` | `CANCELLED` | Cancelled before start | — | Revert room if held; **Audit** |
| `IN_PROGRESS` | `CANCELLED` | Aborted | Admin | Room state reviewed; **Audit** |

### 9.3 Priority (Metadata, Not State)

| Priority | Grid Hint |
|----------|-----------|
| `LOW` | Normal queue |
| `MEDIUM` | Badge |
| `HIGH` | Pulsing / red border on cell |
| `EMERGENCY` | Block room immediately → `MAINTENANCE` |

### 9.4 UI Impact

| State | Maintenance Board | Room Grid |
|-------|---------------------|-----------|
| `REPORTED` | Inbox | Optional flag |
| `SCHEDULED` | Calendar | `MAINTENANCE` |
| `IN_PROGRESS` | Active work | `MAINTENANCE` |
| `COMPLETED` | Archive | Cleared |
| `CANCELLED` | Archive | Cleared |

---

## 10. Cross-Domain Interaction Table

| Source Event | Target Domain | Effect |
|--------------|---------------|--------|
| Lease `ACTIVE` | Room | `OCCUPIED` |
| Lease `TERMINATED` | Room | `VACANT` (after checkout) |
| Lease `CANCELLED` (from pending) | Room | `VACANT` if was `RESERVED` |
| Invoice `ISSUED` | Payment | Create `PENDING` + QR |
| Payment `SUCCEEDED` | Invoice | Allocate; `PAID` / `PARTIALLY_PAID` |
| Payment `SUCCEEDED` | Room/Grid | Refresh badges (overdue cleared) |
| Maintenance `SCHEDULED` / `IN_PROGRESS` | Room | `MAINTENANCE` |
| Maintenance `COMPLETED` | Room | `VACANT` or restore occupied |
| Invoice scheduler `OVERDUE` | Room/Grid | Overdue badge |
| Property config change | Frontend | Re-render matrix dimensions only |

---

## 11. Role-Based Transition Permissions (Summary)

| Transition Category | Roles |
|---------------------|-------|
| Room reserve / release | `STAFF`, `MANAGER` |
| Lease activate / terminate | `MANAGER` (+ `STAFF` draft) |
| Invoice issue / void | `STAFF`, `MANAGER` |
| Write-off | `MANAGER`, `FINANCE` |
| Payment refund | `MANAGER`, `FINANCE` |
| Maintenance CRUD | `STAFF`, `MAINTENANCE_CREW` |
| Out of service | `MANAGER` |
| Webhook processing | `SYSTEM` (actor_type `webhook`) |

---

## 12. DDL Derivation Checklist

When implementing PostgreSQL schema, each domain should produce:

| Domain | Tables (illustrative) | `status` enum |
|--------|----------------------|---------------|
| Property | `properties` | — |
| Room | `rooms` | `room_status` |
| Lease | `leases`, `lease_tenants` | `lease_status` |
| Invoice | `invoices`, `invoice_lines`, `invoice_allocations` | `invoice_status` |
| Payment | `payments`, `payment_webhook_events` | `payment_status` |
| Maintenance | `maintenance_tickets` | `maintenance_status` |
| Shared | `audit_log` | — |

**Constraints to implement:**

- Unique partial index: one `ACTIVE` lease per `room_id`.
- Check: `grid_row` between 1 and `property.grid_rows`, same for columns.
- Unique: `payment_webhook_events.provider_event_id`.
- FK cascades: soft-delete only; never hard-delete leases/invoices with audit trail.

---

## 13. Property Seed Reference (Configuration Only)

| Property | `grid_rows` | `grid_columns` | Rooms | Notes |
|----------|-------------|----------------|-------|-------|
| A | 2 | 7 | 14 | Vacant: 1, 8, 10, 14 |
| B | 2 | 4 | 8 | Near Aranyaprathet District Office |

---

*This state map is locked for Phase 1. Changes require explicit version bump and migration plan.*
