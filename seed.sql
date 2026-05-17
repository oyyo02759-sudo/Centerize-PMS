-- =============================================================================
-- Centerize PMS — Production Seed Data
-- Prerequisite: schema.sql applied successfully
-- Usage:  psql -U <user> -d centerize_pms -f seed.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Idempotent re-seed (development / CI) — reverse dependency order
-- ---------------------------------------------------------------------------
TRUNCATE TABLE
    audit_logs,
    payment_logs,
    payment_webhook_events,
    invoice_allocations,
    payments,
    invoice_lines,
    invoices,
    lease_tenants,
    leases,
    maintenance_tickets,
    rooms,
    tenants,
    properties,
    users,
    organizations
CASCADE;

-- ---------------------------------------------------------------------------
-- 1. Organization
-- ---------------------------------------------------------------------------
INSERT INTO organizations (id, code, name, metadata)
VALUES (
    'a0000000-0000-4000-8000-000000000001',
    'CENTERIZE',
    'Centerize Operations',
    '{"timezone": "Asia/Bangkok", "locale": "th-TH"}'::JSONB
);

-- ---------------------------------------------------------------------------
-- 2. Mock users (RBAC roles per DOMAINS_STATE_MAP.md §11)
-- ---------------------------------------------------------------------------
INSERT INTO users (id, organization_id, email, display_name, role, metadata) VALUES
    (
        'a0000001-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000001',
        'manager@centerize.local',
        'Somsak Manager',
        'MANAGER',
        '{"permissions": ["lease.activate", "lease.terminate", "invoice.void", "payment.refund"]}'::JSONB
    ),
    (
        'a0000001-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000001',
        'staff@centerize.local',
        'Nicha Staff',
        'STAFF',
        '{"permissions": ["room.reserve", "invoice.issue", "maintenance.create"]}'::JSONB
    ),
    (
        'a0000001-0000-4000-8000-000000000003',
        'a0000000-0000-4000-8000-000000000001',
        'finance@centerize.local',
        'Pim Finance',
        'FINANCE',
        '{"permissions": ["invoice.write_off", "payment.refund"]}'::JSONB
    ),
    (
        'a0000001-0000-4000-8000-000000000004',
        'a0000000-0000-4000-8000-000000000001',
        'crew@centerize.local',
        'Boon Maintenance Crew',
        'MAINTENANCE_CREW',
        '{"permissions": ["maintenance.update"]}'::JSONB
    );

-- ---------------------------------------------------------------------------
-- 3. Properties
-- ---------------------------------------------------------------------------
INSERT INTO properties (
    id, organization_id, code, name, address, location_notes,
    grid_rows, grid_columns, metadata
) VALUES
    (
        'b0000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000001',
        'PROPERTY_A',
        'Property A',
        'Bangkok Metropolitan Demo Site',
        NULL,
        2,
        7,
        '{"phase": 1, "prototype": true}'::JSONB
    ),
    (
        'b0000000-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000001',
        'PROPERTY_B',
        'Property B — Aranyaprathet',
        'Sa Kaeo Province',
        'Near Aranyaprathet District Office (อำเภออรัญประเทศ)',
        2,
        4,
        '{"phase": 1, "district": "Aranyaprathet"}'::JSONB
    );

-- ---------------------------------------------------------------------------
-- 4. Property A — 14 rooms (2×7 row-major)
--    Vacant: 1, 8, 10, 14  |  Occupied: all others (10 rooms)
-- ---------------------------------------------------------------------------
INSERT INTO rooms (
    id, property_id, room_number, grid_position_row, grid_position_col, status, label
) VALUES
    ('c1a00000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', '1',  1, 1, 'VACANT',   'Room 1'),
    ('c1a00000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', '2',  1, 2, 'OCCUPIED', 'Room 2'),
    ('c1a00000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', '3',  1, 3, 'OCCUPIED', 'Room 3'),
    ('c1a00000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', '4',  1, 4, 'OCCUPIED', 'Room 4'),
    ('c1a00000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000001', '5',  1, 5, 'OCCUPIED', 'Room 5'),
    ('c1a00000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000001', '6',  1, 6, 'OCCUPIED', 'Room 6'),
    ('c1a00000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000001', '7',  1, 7, 'OCCUPIED', 'Room 7'),
    ('c1a00000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000001', '8',  2, 1, 'VACANT',   'Room 8'),
    ('c1a00000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000001', '9',  2, 2, 'OCCUPIED', 'Room 9'),
    ('c1a00000-0000-4000-8000-00000000000a', 'b0000000-0000-4000-8000-000000000001', '10', 2, 3, 'VACANT',   'Room 10'),
    ('c1a00000-0000-4000-8000-00000000000b', 'b0000000-0000-4000-8000-000000000001', '11', 2, 4, 'OCCUPIED', 'Room 11'),
    ('c1a00000-0000-4000-8000-00000000000c', 'b0000000-0000-4000-8000-000000000001', '12', 2, 5, 'OCCUPIED', 'Room 12'),
    ('c1a00000-0000-4000-8000-00000000000d', 'b0000000-0000-4000-8000-000000000001', '13', 2, 6, 'OCCUPIED', 'Room 13'),
    ('c1a00000-0000-4000-8000-00000000000e', 'b0000000-0000-4000-8000-000000000001', '14', 2, 7, 'VACANT',   'Room 14');

-- ---------------------------------------------------------------------------
-- 5. Property B — 8 rooms (2×4 row-major), all OCCUPIED
-- ---------------------------------------------------------------------------
INSERT INTO rooms (
    id, property_id, room_number, grid_position_row, grid_position_col, status, label
) VALUES
    ('c1b00000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', '1', 1, 1, 'OCCUPIED', 'B-Room 1'),
    ('c1b00000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', '2', 1, 2, 'OCCUPIED', 'B-Room 2'),
    ('c1b00000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002', '3', 1, 3, 'OCCUPIED', 'B-Room 3'),
    ('c1b00000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000002', '4', 1, 4, 'OCCUPIED', 'B-Room 4'),
    ('c1b00000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000002', '5', 2, 1, 'OCCUPIED', 'B-Room 5'),
    ('c1b00000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000002', '6', 2, 2, 'OCCUPIED', 'B-Room 6'),
    ('c1b00000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000002', '7', 2, 3, 'OCCUPIED', 'B-Room 7'),
    ('c1b00000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000002', '8', 2, 4, 'OCCUPIED', 'B-Room 8');

-- ---------------------------------------------------------------------------
-- 6. Tenants (one per occupied room)
-- ---------------------------------------------------------------------------
INSERT INTO tenants (id, organization_id, full_name, phone, email, national_id, metadata) VALUES
    -- Property A (10 tenants — rooms 2,3,4,5,6,7,9,11,12,13)
    ('d1a00000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'Arthit Senanan',   '081-200-0002', 'arthit.a2@tenant.local',  '1102000000002', '{}'),
    ('d1a00000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'Malee Wongsri',    '081-200-0003', 'malee.a3@tenant.local',   '1102000000003', '{}'),
    ('d1a00000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'Kittisak Boonma',  '081-200-0004', 'kittisak.a4@tenant.local','1102000000004', '{}'),
    ('d1a00000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'Siriporn Chai',    '081-200-0005', 'siriporn.a5@tenant.local','1102000000005', '{}'),
    ('d1a00000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'Prasert Thong',    '081-200-0006', 'prasert.a6@tenant.local', '1102000000006', '{}'),
    ('d1a00000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'Wanida Petch',     '081-200-0007', 'wanida.a7@tenant.local',  '1102000000007', '{}'),
    ('d1a00000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000001', 'Surachai Meesri',  '081-200-0009', 'surachai.a9@tenant.local','1102000000009', '{}'),
    ('d1a00000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-000000000001', 'Pornthip Lert',    '081-200-0011', 'pornthip.a11@tenant.local','1102000000011', '{}'),
    ('d1a00000-0000-4000-8000-00000000000c', 'a0000000-0000-4000-8000-000000000001', 'Anan Srisuk',      '081-200-0012', 'anan.a12@tenant.local',   '1102000000012', '{}'),
    ('d1a00000-0000-4000-8000-00000000000d', 'a0000000-0000-4000-8000-000000000001', 'Jintana Rao',      '081-200-0013', 'jintana.a13@tenant.local','1102000000013', '{}'),
    -- Property B (8 tenants)
    ('d1b00000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Chaiwat Aranya',   '085-300-0001', 'chaiwat.b1@tenant.local', '3103000000001', '{}'),
    ('d1b00000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'Suda Prathet',     '085-300-0002', 'suda.b2@tenant.local',    '3103000000002', '{}'),
    ('d1b00000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'Nattapong Rim',    '085-300-0003', 'nattapong.b3@tenant.local','3103000000003', '{}'),
    ('d1b00000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'Orathai Saen',     '085-300-0004', 'orathai.b4@tenant.local', '3103000000004', '{}'),
    ('d1b00000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'Somchai Border',   '085-300-0005', 'somchai.b5@tenant.local', '3103000000005', '{}'),
    ('d1b00000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'Patcharee Moon',    '085-300-0006', 'patcharee.b6@tenant.local','3103000000006', '{}'),
    ('d1b00000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'Teerapat Klang',   '085-300-0007', 'teerapat.b7@tenant.local','3103000000007', '{}'),
    ('d1b00000-0000-4000-8000-000000000008', 'a0000000-0000-4000-8000-000000000001', 'Rattana Poonsuk',  '085-300-0008', 'rattana.b8@tenant.local', '3103000000008', '{}');

-- ---------------------------------------------------------------------------
-- 7. Active leases + lease_tenants
-- ---------------------------------------------------------------------------
INSERT INTO leases (
    id, organization_id, property_id, room_id, primary_tenant_id,
    status, lease_number, monthly_rent, currency,
    start_date, end_date, activated_at, metadata
) VALUES
    -- Property A
    ('e1a00000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000002', 'd1a00000-0000-4000-8000-000000000002', 'ACTIVE', 'LA-2025-002', 4500.00, 'THB', '2025-06-01', '2026-05-31', '2025-06-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000003', 'd1a00000-0000-4000-8000-000000000003', 'ACTIVE', 'LA-2025-003', 4200.00, 'THB', '2025-07-01', '2026-06-30', '2025-07-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000004', 'd1a00000-0000-4000-8000-000000000004', 'ACTIVE', 'LA-2025-004', 4800.00, 'THB', '2025-05-01', '2026-04-30', '2025-05-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000005', 'd1a00000-0000-4000-8000-000000000005', 'ACTIVE', 'LA-2025-005', 4000.00, 'THB', '2025-08-01', '2026-07-31', '2025-08-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000006', 'd1a00000-0000-4000-8000-000000000006', 'ACTIVE', 'LA-2025-006', 4300.00, 'THB', '2025-06-15', '2026-06-14', '2025-06-15 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000007', 'd1a00000-0000-4000-8000-000000000007', 'ACTIVE', 'LA-2025-007', 4100.00, 'THB', '2025-09-01', '2026-08-31', '2025-09-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-000000000009', 'd1a00000-0000-4000-8000-000000000009', 'ACTIVE', 'LA-2025-009', 4600.00, 'THB', '2025-04-01', '2026-03-31', '2025-04-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-00000000000b', 'd1a00000-0000-4000-8000-00000000000b', 'ACTIVE', 'LA-2025-011', 4400.00, 'THB', '2025-10-01', '2026-09-30', '2025-10-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-00000000000c', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-00000000000c', 'd1a00000-0000-4000-8000-00000000000c', 'ACTIVE', 'LA-2025-012', 4700.00, 'THB', '2025-03-01', '2026-02-28', '2025-03-01 10:00:00+07', '{}'),
    ('e1a00000-0000-4000-8000-00000000000d', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c1a00000-0000-4000-8000-00000000000d', 'd1a00000-0000-4000-8000-00000000000d', 'ACTIVE', 'LA-2025-013', 5000.00, 'THB', '2025-11-01', '2026-10-31', '2025-11-01 10:00:00+07', '{}'),
    -- Property B
    ('e1b00000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000001', 'd1b00000-0000-4000-8000-000000000001', 'ACTIVE', 'LB-2025-001', 3800.00, 'THB', '2025-06-01', '2026-05-31', '2025-06-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000002', 'd1b00000-0000-4000-8000-000000000002', 'ACTIVE', 'LB-2025-002', 3600.00, 'THB', '2025-06-01', '2026-05-31', '2025-06-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000003', 'd1b00000-0000-4000-8000-000000000003', 'ACTIVE', 'LB-2025-003', 3900.00, 'THB', '2025-07-01', '2026-06-30', '2025-07-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000004', 'd1b00000-0000-4000-8000-000000000004', 'ACTIVE', 'LB-2025-004', 3700.00, 'THB', '2025-08-01', '2026-07-31', '2025-08-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000005', 'd1b00000-0000-4000-8000-000000000005', 'ACTIVE', 'LB-2025-005', 4000.00, 'THB', '2025-05-01', '2026-04-30', '2025-05-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000006', 'd1b00000-0000-4000-8000-000000000006', 'ACTIVE', 'LB-2025-006', 3850.00, 'THB', '2025-09-01', '2026-08-31', '2025-09-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000007', 'd1b00000-0000-4000-8000-000000000007', 'ACTIVE', 'LB-2025-007', 3950.00, 'THB', '2025-04-01', '2026-03-31', '2025-04-01 09:00:00+07', '{}'),
    ('e1b00000-0000-4000-8000-000000000008', 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002', 'c1b00000-0000-4000-8000-000000000008', 'd1b00000-0000-4000-8000-000000000008', 'ACTIVE', 'LB-2025-008', 4100.00, 'THB', '2025-10-01', '2026-09-30', '2025-10-01 09:00:00+07', '{}');

INSERT INTO lease_tenants (id, lease_id, tenant_id, is_primary) VALUES
    ('f1a00000-0000-4000-8000-000000000002', 'e1a00000-0000-4000-8000-000000000002', 'd1a00000-0000-4000-8000-000000000002', TRUE),
    ('f1a00000-0000-4000-8000-000000000003', 'e1a00000-0000-4000-8000-000000000003', 'd1a00000-0000-4000-8000-000000000003', TRUE),
    ('f1a00000-0000-4000-8000-000000000004', 'e1a00000-0000-4000-8000-000000000004', 'd1a00000-0000-4000-8000-000000000004', TRUE),
    ('f1a00000-0000-4000-8000-000000000005', 'e1a00000-0000-4000-8000-000000000005', 'd1a00000-0000-4000-8000-000000000005', TRUE),
    ('f1a00000-0000-4000-8000-000000000006', 'e1a00000-0000-4000-8000-000000000006', 'd1a00000-0000-4000-8000-000000000006', TRUE),
    ('f1a00000-0000-4000-8000-000000000007', 'e1a00000-0000-4000-8000-000000000007', 'd1a00000-0000-4000-8000-000000000007', TRUE),
    ('f1a00000-0000-4000-8000-000000000009', 'e1a00000-0000-4000-8000-000000000009', 'd1a00000-0000-4000-8000-000000000009', TRUE),
    ('f1a00000-0000-4000-8000-00000000000b', 'e1a00000-0000-4000-8000-00000000000b', 'd1a00000-0000-4000-8000-00000000000b', TRUE),
    ('f1a00000-0000-4000-8000-00000000000c', 'e1a00000-0000-4000-8000-00000000000c', 'd1a00000-0000-4000-8000-00000000000c', TRUE),
    ('f1a00000-0000-4000-8000-00000000000d', 'e1a00000-0000-4000-8000-00000000000d', 'd1a00000-0000-4000-8000-00000000000d', TRUE),
    ('f1b00000-0000-4000-8000-000000000001', 'e1b00000-0000-4000-8000-000000000001', 'd1b00000-0000-4000-8000-000000000001', TRUE),
    ('f1b00000-0000-4000-8000-000000000002', 'e1b00000-0000-4000-8000-000000000002', 'd1b00000-0000-4000-8000-000000000002', TRUE),
    ('f1b00000-0000-4000-8000-000000000003', 'e1b00000-0000-4000-8000-000000000003', 'd1b00000-0000-4000-8000-000000000003', TRUE),
    ('f1b00000-0000-4000-8000-000000000004', 'e1b00000-0000-4000-8000-000000000004', 'd1b00000-0000-4000-8000-000000000004', TRUE),
    ('f1b00000-0000-4000-8000-000000000005', 'e1b00000-0000-4000-8000-000000000005', 'd1b00000-0000-4000-8000-000000000005', TRUE),
    ('f1b00000-0000-4000-8000-000000000006', 'e1b00000-0000-4000-8000-000000000006', 'd1b00000-0000-4000-8000-000000000006', TRUE),
    ('f1b00000-0000-4000-8000-000000000007', 'e1b00000-0000-4000-8000-000000000007', 'd1b00000-0000-4000-8000-000000000007', TRUE),
    ('f1b00000-0000-4000-8000-000000000008', 'e1b00000-0000-4000-8000-000000000008', 'd1b00000-0000-4000-8000-000000000008', TRUE);

-- ---------------------------------------------------------------------------
-- 8. Sample invoices (rent + utility line items)
-- ---------------------------------------------------------------------------

-- PAID — Property A Room 2 (April 2026, settled via Omise PromptPay)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, paid_at, notes, metadata
) VALUES (
    '10000001-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'e1a00000-0000-4000-8000-000000000002',
    'c1a00000-0000-4000-8000-000000000002',
    'd1a00000-0000-4000-8000-000000000002',
    'INV-2026-A-R02-04',
    'PAID',
    5250.00, 0.00, 5250.00, 5250.00,
    '2026-04-10', '2026-04-01 08:00:00+07', '2026-04-05 14:22:00+07',
    'April 2026 — rent + utilities',
    '{"billing_period": "2026-04", "property_code": "PROPERTY_A"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000001-0000-4000-8000-000000000001', '10000001-0000-4000-8000-000000000001', 1, 'Monthly rent — Room 2', 1, 4500.00, 4500.00, '{"line_type": "rent"}'::JSONB),
    ('11000001-0000-4000-8000-000000000002', '10000001-0000-4000-8000-000000000001', 2, 'Electricity', 142, 5.00, 710.00,
     '{"utility_type": "electricity", "unit": "kWh", "previous_reading": 1180, "current_reading": 1322, "units": 142, "rate_per_unit": 5.00}'::JSONB),
    ('11000001-0000-4000-8000-000000000003', '10000001-0000-4000-8000-000000000001', 3, 'Water', 8, 5.00, 40.00,
     '{"utility_type": "water", "unit": "m3", "previous_reading": 210, "current_reading": 218, "units": 8, "rate_per_unit": 5.00}'::JSONB);

-- ISSUED (unpaid) — Property A Room 3 (May 2026)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, notes, metadata
) VALUES (
    '10000001-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'e1a00000-0000-4000-8000-000000000003',
    'c1a00000-0000-4000-8000-000000000003',
    'd1a00000-0000-4000-8000-000000000003',
    'INV-2026-A-R03-05',
    'ISSUED',
    4910.00, 0.00, 4910.00, 0.00,
    '2026-05-10', '2026-05-01 08:00:00+07',
    'May 2026 — awaiting PromptPay',
    '{"billing_period": "2026-05", "property_code": "PROPERTY_A"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000001-0000-4000-8000-000000000004', '10000001-0000-4000-8000-000000000002', 1, 'Monthly rent — Room 3', 1, 4200.00, 4200.00, '{"line_type": "rent"}'::JSONB),
    ('11000001-0000-4000-8000-000000000005', '10000001-0000-4000-8000-000000000002', 2, 'Electricity', 128, 5.00, 640.00,
     '{"utility_type": "electricity", "unit": "kWh", "previous_reading": 940, "current_reading": 1068, "units": 128, "rate_per_unit": 5.00}'::JSONB),
    ('11000001-0000-4000-8000-000000000006', '10000001-0000-4000-8000-000000000002', 3, 'Water', 14, 5.00, 70.00,
     '{"utility_type": "water", "unit": "m3", "previous_reading": 155, "current_reading": 169, "units": 14, "rate_per_unit": 5.00}'::JSONB);

-- OVERDUE (unpaid) — Property A Room 4 (April 2026, past due)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, notes, metadata
) VALUES (
    '10000001-0000-4000-8000-000000000003',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'e1a00000-0000-4000-8000-000000000004',
    'c1a00000-0000-4000-8000-000000000004',
    'd1a00000-0000-4000-8000-000000000004',
    'INV-2026-A-R04-04',
    'OVERDUE',
    5380.00, 0.00, 5380.00, 0.00,
    '2026-04-10', '2026-04-01 08:00:00+07',
    'April 2026 — overdue collections',
    '{"billing_period": "2026-04", "property_code": "PROPERTY_A", "collections_flag": true}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000001-0000-4000-8000-000000000007', '10000001-0000-4000-8000-000000000003', 1, 'Monthly rent — Room 4', 1, 4800.00, 4800.00, '{"line_type": "rent"}'::JSONB),
    ('11000001-0000-4000-8000-000000000008', '10000001-0000-4000-8000-000000000003', 2, 'Electricity', 98, 5.00, 490.00,
     '{"utility_type": "electricity", "unit": "kWh", "previous_reading": 2201, "current_reading": 2299, "units": 98, "rate_per_unit": 5.00}'::JSONB),
    ('11000001-0000-4000-8000-000000000009', '10000001-0000-4000-8000-000000000003', 3, 'Water', 18, 5.00, 90.00,
     '{"utility_type": "water", "unit": "m3", "previous_reading": 88, "current_reading": 106, "units": 18, "rate_per_unit": 5.00}'::JSONB);

-- ISSUED (unpaid) — Property A Room 5 (May 2026)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, notes, metadata
) VALUES (
    '10000001-0000-4000-8000-000000000004',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'e1a00000-0000-4000-8000-000000000005',
    'c1a00000-0000-4000-8000-000000000005',
    'd1a00000-0000-4000-8000-000000000005',
    'INV-2026-A-R05-05',
    'ISSUED',
    4320.00, 0.00, 4320.00, 0.00,
    '2026-05-10', '2026-05-01 08:00:00+07',
    'May 2026',
    '{"billing_period": "2026-05"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000001-0000-4000-8000-00000000000a', '10000001-0000-4000-8000-000000000004', 1, 'Monthly rent — Room 5', 1, 4000.00, 4000.00, '{"line_type": "rent"}'::JSONB),
    ('11000001-0000-4000-8000-00000000000b', '10000001-0000-4000-8000-000000000004', 2, 'Electricity', 52, 5.00, 260.00,
     '{"utility_type": "electricity", "previous_reading": 501, "current_reading": 553, "units": 52}'::JSONB),
    ('11000001-0000-4000-8000-00000000000c', '10000001-0000-4000-8000-000000000004', 3, 'Water', 12, 5.00, 60.00,
     '{"utility_type": "water", "previous_reading": 44, "current_reading": 56, "units": 12}'::JSONB);

-- PAID — Property B Room 1 (April 2026)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, paid_at, notes, metadata
) VALUES (
    '10000002-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000002',
    'e1b00000-0000-4000-8000-000000000001',
    'c1b00000-0000-4000-8000-000000000001',
    'd1b00000-0000-4000-8000-000000000001',
    'INV-2026-B-R01-04',
    'PAID',
    4190.00, 0.00, 4190.00, 4190.00,
    '2026-04-10', '2026-04-01 08:00:00+07', '2026-04-08 11:05:00+07',
    'April 2026 — Aranyaprathet Property B',
    '{"billing_period": "2026-04", "property_code": "PROPERTY_B"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000002-0000-4000-8000-000000000001', '10000002-0000-4000-8000-000000000001', 1, 'Monthly rent — B-Room 1', 1, 3800.00, 3800.00, '{"line_type": "rent"}'::JSONB),
    ('11000002-0000-4000-8000-000000000002', '10000002-0000-4000-8000-000000000001', 2, 'Electricity', 68, 5.00, 340.00,
     '{"utility_type": "electricity", "previous_reading": 402, "current_reading": 470, "units": 68}'::JSONB),
    ('11000002-0000-4000-8000-000000000003', '10000002-0000-4000-8000-000000000001', 3, 'Water', 10, 5.00, 50.00,
     '{"utility_type": "water", "previous_reading": 72, "current_reading": 82, "units": 10}'::JSONB);

-- ISSUED (unpaid) — Property B Room 2 (May 2026)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, notes, metadata
) VALUES (
    '10000002-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000002',
    'e1b00000-0000-4000-8000-000000000002',
    'c1b00000-0000-4000-8000-000000000002',
    'd1b00000-0000-4000-8000-000000000002',
    'INV-2026-B-R02-05',
    'ISSUED',
    3880.00, 0.00, 3880.00, 0.00,
    '2026-05-10', '2026-05-01 08:00:00+07',
    'May 2026 — Aranyaprathet',
    '{"billing_period": "2026-05", "property_code": "PROPERTY_B"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000002-0000-4000-8000-000000000004', '10000002-0000-4000-8000-000000000002', 1, 'Monthly rent — B-Room 2', 1, 3600.00, 3600.00, '{"line_type": "rent"}'::JSONB),
    ('11000002-0000-4000-8000-000000000005', '10000002-0000-4000-8000-000000000002', 2, 'Electricity', 44, 5.00, 220.00,
     '{"utility_type": "electricity", "previous_reading": 310, "current_reading": 354, "units": 44}'::JSONB),
    ('11000002-0000-4000-8000-000000000006', '10000002-0000-4000-8000-000000000002', 3, 'Water', 12, 5.00, 60.00,
     '{"utility_type": "water", "previous_reading": 19, "current_reading": 31, "units": 12}'::JSONB);

-- OVERDUE — Property B Room 5 (April 2026)
INSERT INTO invoices (
    id, organization_id, property_id, lease_id, room_id, tenant_id,
    invoice_number, status, subtotal_amount, tax_amount, total_amount, amount_paid,
    due_date, issued_at, notes, metadata
) VALUES (
    '10000002-0000-4000-8000-000000000003',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000002',
    'e1b00000-0000-4000-8000-000000000005',
    'c1b00000-0000-4000-8000-000000000005',
    'd1b00000-0000-4000-8000-000000000005',
    'INV-2026-B-R05-04',
    'OVERDUE',
    4350.00, 0.00, 4350.00, 0.00,
    '2026-04-10', '2026-04-01 08:00:00+07',
    'April 2026 — overdue',
    '{"billing_period": "2026-04", "property_code": "PROPERTY_B"}'::JSONB
);

INSERT INTO invoice_lines (id, invoice_id, line_number, description, quantity, unit_price, line_total, metadata) VALUES
    ('11000002-0000-4000-8000-000000000007', '10000002-0000-4000-8000-000000000003', 1, 'Monthly rent — B-Room 5', 1, 4000.00, 4000.00, '{"line_type": "rent"}'::JSONB),
    ('11000002-0000-4000-8000-000000000008', '10000002-0000-4000-8000-000000000003', 2, 'Electricity', 58, 5.00, 290.00,
     '{"utility_type": "electricity", "previous_reading": 880, "current_reading": 938, "units": 58}'::JSONB),
    ('11000002-0000-4000-8000-000000000009', '10000002-0000-4000-8000-000000000003', 3, 'Water', 12, 5.00, 60.00,
     '{"utility_type": "water", "previous_reading": 33, "current_reading": 45, "units": 12}'::JSONB);

-- ---------------------------------------------------------------------------
-- 9. Payments, allocations, webhook events (paid invoices only)
-- ---------------------------------------------------------------------------

-- Payment for INV-2026-A-R02-04 (succeeded)
INSERT INTO payments (
    id, organization_id, invoice_id, status, provider, amount, currency,
    idempotency_key, provider_charge_id, provider_transaction_id,
    qr_payload, provider_metadata, succeeded_at
) VALUES (
    '12000001-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    '10000001-0000-4000-8000-000000000001',
    'SUCCEEDED',
    'omise',
    5250.00,
    'THB',
    'pay-idem-2026-a-r02-04',
    'chrg_test_a_r02_04',
    'trxn_test_a_r02_04',
    '{"promptpay_qr": "https://api.omise.co/qr/demo-a-r02-04", "expires_at": "2026-04-10T23:59:59+07:00"}'::JSONB,
    '{"source": "promptpay", "brand": "promptpay"}'::JSONB,
    '2026-04-05 14:22:00+07'
);

INSERT INTO invoice_allocations (id, payment_id, invoice_id, amount, metadata) VALUES (
    '13000001-0000-4000-8000-000000000001',
    '12000001-0000-4000-8000-000000000001',
    '10000001-0000-4000-8000-000000000001',
    5250.00,
    '{"reconciliation": "full"}'::JSONB
);

INSERT INTO payment_webhook_events (
    id, organization_id, payment_id, provider, provider_event_id,
    provider_transaction_id, event_type, processing_status, signature_verified,
    raw_payload, processed_at
) VALUES (
    '14000001-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    '12000001-0000-4000-8000-000000000001',
    'omise',
    'evt_test_a_r02_04_charge_complete',
    'trxn_test_a_r02_04',
    'charge.complete',
    'PROCESSED',
    TRUE,
    '{"key": "chrg_test_a_r02_04", "amount": 525000, "currency": "thb", "status": "successful"}'::JSONB,
    '2026-04-05 14:22:01+07'
);

INSERT INTO payment_logs (
    id, payment_id, invoice_id, organization_id,
    log_type, from_status, to_status, provider,
    provider_event_id, provider_transaction_id, idempotency_key, amount, message, metadata
) VALUES (
    '15000001-0000-4000-8000-000000000001',
    '12000001-0000-4000-8000-000000000001',
    '10000001-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'webhook.reconciled',
    'PROCESSING',
    'SUCCEEDED',
    'omise',
    'evt_test_a_r02_04_charge_complete',
    'trxn_test_a_r02_04',
    'pay-idem-2026-a-r02-04',
    5250.00,
    'PromptPay settlement applied to invoice INV-2026-A-R02-04',
    '{"actor": "webhook"}'::JSONB
);

-- Pending payment + QR for unpaid ISSUED invoice (Room 3)
INSERT INTO payments (
    id, organization_id, invoice_id, status, provider, amount, currency,
    idempotency_key, provider_charge_id, qr_payload, expires_at
) VALUES (
    '12000001-0000-4000-8000-000000000002',
    'a0000000-0000-4000-8000-000000000001',
    '10000001-0000-4000-8000-000000000002',
    'PENDING',
    'opn',
    4910.00,
    'THB',
    'pay-idem-2026-a-r03-05',
    'chrg_test_a_r03_05',
    '{"promptpay_qr": "https://api.opn.ooo/qr/demo-a-r03-05", "expires_at": "2026-05-10T23:59:59+07:00"}'::JSONB,
    '2026-05-10 23:59:59+07'
);

-- Payment for INV-2026-B-R01-04 (succeeded)
INSERT INTO payments (
    id, organization_id, invoice_id, status, provider, amount, currency,
    idempotency_key, provider_charge_id, provider_transaction_id,
    qr_payload, provider_metadata, succeeded_at
) VALUES (
    '12000002-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    '10000002-0000-4000-8000-000000000001',
    'SUCCEEDED',
    'omise',
    4190.00,
    'THB',
    'pay-idem-2026-b-r01-04',
    'chrg_test_b_r01_04',
    'trxn_test_b_r01_04',
    '{"promptpay_qr": "https://api.omise.co/qr/demo-b-r01-04"}'::JSONB,
    '{"source": "promptpay"}'::JSONB,
    '2026-04-08 11:05:00+07'
);

INSERT INTO invoice_allocations (id, payment_id, invoice_id, amount) VALUES (
    '13000002-0000-4000-8000-000000000001',
    '12000002-0000-4000-8000-000000000001',
    '10000002-0000-4000-8000-000000000001',
    4190.00
);

INSERT INTO payment_webhook_events (
    id, organization_id, payment_id, provider, provider_event_id,
    provider_transaction_id, event_type, processing_status, signature_verified,
    raw_payload, processed_at
) VALUES (
    '14000002-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    '12000002-0000-4000-8000-000000000001',
    'omise',
    'evt_test_b_r01_04_charge_complete',
    'trxn_test_b_r01_04',
    'charge.complete',
    'PROCESSED',
    TRUE,
    '{"key": "chrg_test_b_r01_04", "amount": 419000, "status": "successful"}'::JSONB,
    '2026-04-08 11:05:01+07'
);

-- ---------------------------------------------------------------------------
-- 10. Sample maintenance ticket (Property A Room 12 — occupied)
-- ---------------------------------------------------------------------------
INSERT INTO maintenance_tickets (
    id, organization_id, property_id, room_id, ticket_number,
    status, priority, title, description,
    reported_at, reported_by, assigned_to, metadata
) VALUES (
    '16000001-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'c1a00000-0000-4000-8000-00000000000c',
    'MT-2026-A-001',
    'REPORTED',
    'MEDIUM',
    'AC unit intermittent cooling',
    'Tenant reports AC cycles off every 2 hours. Room remains occupied.',
    '2026-05-15 09:30:00+07',
    'a0000001-0000-4000-8000-000000000002',
    'a0000001-0000-4000-8000-000000000004',
    '{"property_code": "PROPERTY_A", "room_number": "12"}'::JSONB
);

-- ---------------------------------------------------------------------------
-- 11. Bootstrap audit trail (seed actor = staff user)
-- ---------------------------------------------------------------------------
INSERT INTO audit_logs (
    id, organization_id, property_id, entity_type, entity_id,
    action, from_state, to_state, actor_id, actor_type, correlation_id, metadata, occurred_at
) VALUES
    (
        '17000001-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000001',
        'lease', 'e1a00000-0000-4000-8000-000000000002',
        'state.transition', 'PENDING_SIGNATURE', 'ACTIVE',
        'a0000001-0000-4000-8000-000000000001', 'user', 'seed-bootstrap',
        '{"source": "seed.sql", "note": "Lease activated for Property A Room 2"}'::JSONB,
        '2025-06-01 10:00:00+07'
    ),
    (
        '17000001-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000001',
        'room', 'c1a00000-0000-4000-8000-000000000002',
        'state.transition', 'VACANT', 'OCCUPIED',
        'a0000001-0000-4000-8000-000000000001', 'user', 'seed-bootstrap',
        '{"source": "seed.sql"}'::JSONB,
        '2025-06-01 10:00:01+07'
    ),
    (
        '17000001-0000-4000-8000-000000000003',
        'a0000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000001',
        'invoice', '10000001-0000-4000-8000-000000000001',
        'state.transition', 'ISSUED', 'PAID',
        NULL, 'webhook', 'evt_test_a_r02_04_charge_complete',
        '{"source": "seed.sql", "payment_id": "12000001-0000-4000-8000-000000000001"}'::JSONB,
        '2026-04-05 14:22:01+07'
    ),
    (
        '17000001-0000-4000-8000-000000000004',
        'a0000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000002',
        'lease', 'e1b00000-0000-4000-8000-000000000001',
        'state.transition', 'PENDING_SIGNATURE', 'ACTIVE',
        'a0000001-0000-4000-8000-000000000001', 'user', 'seed-bootstrap',
        '{"source": "seed.sql", "property": "PROPERTY_B"}'::JSONB,
        '2025-06-01 09:00:00+07'
    );

COMMIT;

-- ---------------------------------------------------------------------------
-- Verification queries (optional — run manually after seed)
-- ---------------------------------------------------------------------------
-- SELECT code, grid_rows, grid_columns FROM properties ORDER BY code;
-- SELECT room_number, grid_position_row, grid_position_col, status
--   FROM rooms WHERE property_id = 'b0000000-0000-4000-8000-000000000001' ORDER BY room_number::INT;
-- SELECT status, COUNT(*) FROM invoices GROUP BY status ORDER BY status;
