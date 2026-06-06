# Centerize-PMS
A high-reliability, multi-property management system (PMS) featuring a dynamic room grid matrix, real-time WebSocket state propagation, and automated Opn/Omise PromptPay QR code webhook reconciliation. Built with NestJS, PostgreSQL, and Next.js.

# Centerize PMS (Property Management System)

Centerize PMS is a production-grade, highly scalable **Multi-Property Management System** designed to streamline operations, optimize room grids, and automate financial workflows across multiple residential or commercial buildings. Inspired by modern PMS workflows, the system is engineered from the ground up to eliminate structural rigidity and manual billing errors.

## 🚀 Key Features

* **100% Dynamic Room Grid Matrix:** No hard-coded layouts. Property layouts are entirely data-driven (configured via `grid_rows` and `grid_columns`), allowing the frontend to dynamically render unequal room/floor matrices for unlimited properties (e.g., Property A 2×7 grid, Property B 2×4 grid).
* **Real-Time State Propagation:** Powered by WebSockets (Socket.io/NestJS) to broadcast instantaneous room and lease lifecycle state shifts directly to the staff dashboard.
* **Automated Payment Reconciliation:** Integrated with Opn Payments (Omise) to generate dynamic PromptPay QR codes. Includes a strict, 10-step asynchronous, idempotent webhook processing pipeline to prevent duplicate transactions (double-charging) and automate invoice settlement.
* **Strict State Machine Constraints:** Business logic is locked at both the application and database levels (PostgreSQL Enums & Triggers), ensuring completely valid state transitions for Rooms, Leases, Invoices, Payments, and Maintenance.
* **Centralized Audit Logging:** Enterprise-ready Role-Based Access Control (RBAC) paired with automated logging capturing exact metadata, timestamps, and target domains for every state mutation.

## 🛠️ Technical Stack

* **Backend:** NestJS (TypeScript), TypeORM / Prisma
* **Database:** PostgreSQL (with custom ENUMs, triggers, and partial unique indexes)
* **Real-time:** Socket.io (WebSockets)
* **Payment Gateway:** Opn / Omise API (PromptPay Dynamic QR & Webhooks)
* **Frontend:** React / Next.js (Dynamic Grid Architecture)

## 📂 Project Structure Baseline

```text
├── centerize_pms_agents/   # Specialized AI Agent specifications (Choely, Yo, etc.)
├── docs/                   # System briefs, state mapping, and sprint logs
├── src/                    # NestJS Core Application Workspace
│   └── modules/
│       ├── property/       # Dynamic grid layout engine
│       ├── billing/        # Invoice processing & Omise Adapter
│       ├── webhook/        # Idempotent webhook processor
│       └── websocket/      # Real-time state propagation gateway
├── schema.sql              # Production-ready PostgreSQL DDL & Constraints
└── seed.sql                # Deterministic UUID reference test data
