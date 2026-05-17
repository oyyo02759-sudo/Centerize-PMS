-- =============================================================================
-- Centerize PMS — Production PostgreSQL DDL
-- Derived from: DOMAINS_STATE_MAP.md §12, PROJECT_BRIEF.md
-- Target: PostgreSQL 15+
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------------
-- Custom ENUM types (domain state machines)
-- ---------------------------------------------------------------------------
CREATE TYPE room_status AS ENUM (
    'VACANT',
    'RESERVED',
    'OCCUPIED',
    'MAINTENANCE',
    'OUT_OF_SERVICE'
);

CREATE TYPE lease_status AS ENUM (
    'DRAFT',
    'PENDING_SIGNATURE',
    'ACTIVE',
    'NOTICE_GIVEN',
    'TERMINATED',
    'CANCELLED'
);

CREATE TYPE invoice_status AS ENUM (
    'DRAFT',
    'ISSUED',
    'PARTIALLY_PAID',
    'PAID',
    'OVERDUE',
    'VOID',
    'WRITTEN_OFF'
);

CREATE TYPE payment_status AS ENUM (
    'PENDING',
    'PROCESSING',
    'SUCCEEDED',
    'FAILED',
    'EXPIRED',
    'REFUNDED'
);

CREATE TYPE maintenance_status AS ENUM (
    'REPORTED',
    'SCHEDULED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED'
);

CREATE TYPE maintenance_priority AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'EMERGENCY'
);

CREATE TYPE actor_type AS ENUM (
    'user',
    'system',
    'webhook'
);

CREATE TYPE webhook_event_status AS ENUM (
    'RECEIVED',
    'PROCESSING',
    'PROCESSED',
    'FAILED'
);

CREATE TYPE payment_provider AS ENUM (
    'omise',
    'opn'
);

-- ---------------------------------------------------------------------------
-- Utility: updated_at trigger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Utility: validate room grid position within property bounds
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_room_grid_position()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_grid_rows    INTEGER;
    v_grid_columns INTEGER;
BEGIN
    SELECT p.grid_rows, p.grid_columns
    INTO v_grid_rows, v_grid_columns
    FROM properties p
    WHERE p.id = NEW.property_id
      AND p.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'property % does not exist or is deleted', NEW.property_id;
    END IF;

    IF NEW.grid_position_row < 1 OR NEW.grid_position_row > v_grid_rows THEN
        RAISE EXCEPTION 'grid_position_row % out of bounds [1, %] for property %',
            NEW.grid_position_row, v_grid_rows, NEW.property_id;
    END IF;

    IF NEW.grid_position_col < 1 OR NEW.grid_position_col > v_grid_columns THEN
        RAISE EXCEPTION 'grid_position_col % out of bounds [1, %] for property %',
            NEW.grid_position_col, v_grid_columns, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Organizations (multi-operator / future tenancy)
-- ---------------------------------------------------------------------------
CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            CITEXT NOT NULL,
    name            TEXT NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT organizations_code_not_empty CHECK (length(trim(code::TEXT)) > 0),
    CONSTRAINT organizations_name_not_empty CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX organizations_code_active_uidx
    ON organizations (code)
    WHERE deleted_at IS NULL;

CREATE TRIGGER organizations_set_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Users (audit actors — staff / managers)
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations (id),
    email           CITEXT NOT NULL,
    display_name    TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'STAFF',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT users_email_not_empty CHECK (length(trim(email::TEXT)) > 0),
    CONSTRAINT users_display_name_not_empty CHECK (length(trim(display_name)) > 0),
    CONSTRAINT users_role_not_empty CHECK (length(trim(role)) > 0)
);

CREATE UNIQUE INDEX users_org_email_active_uidx
    ON users (organization_id, email)
    WHERE deleted_at IS NULL;

CREATE INDEX users_organization_id_idx ON users (organization_id);

CREATE TRIGGER users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Properties (dynamic grid configuration)
-- ---------------------------------------------------------------------------
CREATE TABLE properties (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations (id),
    code            CITEXT NOT NULL,
    name            TEXT NOT NULL,
    address         TEXT,
    location_notes  TEXT,
    grid_rows       INTEGER NOT NULL,
    grid_columns    INTEGER NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT properties_code_not_empty CHECK (length(trim(code::TEXT)) > 0),
    CONSTRAINT properties_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT properties_grid_rows_positive CHECK (grid_rows >= 1),
    CONSTRAINT properties_grid_columns_positive CHECK (grid_columns >= 1)
);

CREATE UNIQUE INDEX properties_org_code_active_uidx
    ON properties (organization_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX properties_organization_id_idx ON properties (organization_id);

CREATE TRIGGER properties_set_updated_at
    BEFORE UPDATE ON properties
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE properties IS 'Multi-property root; grid_rows/grid_columns drive dynamic RoomGridMatrix UI.';
COMMENT ON COLUMN properties.location_notes IS 'E.g. Property B: near Aranyaprathet District Office.';

-- ---------------------------------------------------------------------------
-- Rooms (spatial matrix cells)
-- ---------------------------------------------------------------------------
CREATE TABLE rooms (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id         UUID NOT NULL REFERENCES properties (id),
    room_number         TEXT NOT NULL,
    grid_position_row   INTEGER NOT NULL,
    grid_position_col   INTEGER NOT NULL,
    status              room_status NOT NULL DEFAULT 'VACANT',
    is_active_cell      BOOLEAN NOT NULL DEFAULT TRUE,
    label               TEXT,
    metadata            JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT rooms_room_number_not_empty CHECK (length(trim(room_number)) > 0),
    CONSTRAINT rooms_grid_position_row_positive CHECK (grid_position_row >= 1),
    CONSTRAINT rooms_grid_position_col_positive CHECK (grid_position_col >= 1)
);

CREATE UNIQUE INDEX rooms_property_room_number_active_uidx
    ON rooms (property_id, room_number)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX rooms_property_grid_cell_active_uidx
    ON rooms (property_id, grid_position_row, grid_position_col)
    WHERE deleted_at IS NULL AND is_active_cell = TRUE;

CREATE INDEX rooms_property_id_idx ON rooms (property_id);
CREATE INDEX rooms_property_status_idx ON rooms (property_id, status);

CREATE TRIGGER rooms_set_updated_at
    BEFORE UPDATE ON rooms
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER rooms_validate_grid_position
    BEFORE INSERT OR UPDATE OF property_id, grid_position_row, grid_position_col
    ON rooms
    FOR EACH ROW EXECUTE FUNCTION validate_room_grid_position();

COMMENT ON COLUMN rooms.grid_position_row IS '1-based row index within property grid_rows.';
COMMENT ON COLUMN rooms.grid_position_col IS '1-based column index within property grid_columns.';

-- ---------------------------------------------------------------------------
-- Tenants
-- ---------------------------------------------------------------------------
CREATE TABLE tenants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations (id),
    full_name       TEXT NOT NULL,
    phone           TEXT,
    email           CITEXT,
    national_id     TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT tenants_full_name_not_empty CHECK (length(trim(full_name)) > 0)
);

CREATE INDEX tenants_organization_id_idx ON tenants (organization_id);
CREATE INDEX tenants_phone_idx ON tenants (phone) WHERE phone IS NOT NULL;

CREATE TRIGGER tenants_set_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Leases (contract lifecycle + active intervals)
-- ---------------------------------------------------------------------------
CREATE TABLE leases (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID NOT NULL REFERENCES organizations (id),
    property_id         UUID NOT NULL REFERENCES properties (id),
    room_id             UUID NOT NULL REFERENCES rooms (id),
    primary_tenant_id   UUID NOT NULL REFERENCES tenants (id),
    status              lease_status NOT NULL DEFAULT 'DRAFT',
    lease_number        TEXT,
    monthly_rent        NUMERIC(12, 2) NOT NULL,
    currency            CHAR(3) NOT NULL DEFAULT 'THB',
    start_date          DATE,
    end_date            DATE,
    notice_given_at     TIMESTAMPTZ,
    activated_at        TIMESTAMPTZ,
    terminated_at       TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    metadata            JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT leases_monthly_rent_non_negative CHECK (monthly_rent >= 0),
    CONSTRAINT leases_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT leases_date_order CHECK (
        start_date IS NULL
        OR end_date IS NULL
        OR end_date >= start_date
    ),
    CONSTRAINT leases_activated_when_active CHECK (
        status NOT IN ('ACTIVE', 'NOTICE_GIVEN', 'TERMINATED')
        OR activated_at IS NOT NULL
    ),
    CONSTRAINT leases_terminated_timestamp CHECK (
        status <> 'TERMINATED' OR terminated_at IS NOT NULL
    ),
    CONSTRAINT leases_cancelled_timestamp CHECK (
        status <> 'CANCELLED' OR cancelled_at IS NOT NULL
    )
);

-- At most one occupying lease per room (ACTIVE or NOTICE_GIVEN)
CREATE UNIQUE INDEX leases_one_active_per_room_uidx
    ON leases (room_id)
    WHERE deleted_at IS NULL
      AND status IN ('ACTIVE', 'NOTICE_GIVEN');

CREATE INDEX leases_property_id_idx ON leases (property_id);
CREATE INDEX leases_room_id_idx ON leases (room_id);
CREATE INDEX leases_primary_tenant_id_idx ON leases (primary_tenant_id);
CREATE INDEX leases_status_idx ON leases (status);

CREATE TRIGGER leases_set_updated_at
    BEFORE UPDATE ON leases
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Lease ↔ Tenant junction (co-tenants)
-- ---------------------------------------------------------------------------
CREATE TABLE lease_tenants (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lease_id    UUID NOT NULL REFERENCES leases (id),
    tenant_id   UUID NOT NULL REFERENCES tenants (id),
    is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT lease_tenants_unique_pair UNIQUE (lease_id, tenant_id)
);

CREATE UNIQUE INDEX lease_tenants_one_primary_per_lease_uidx
    ON lease_tenants (lease_id)
    WHERE is_primary = TRUE;

CREATE INDEX lease_tenants_tenant_id_idx ON lease_tenants (tenant_id);

-- ---------------------------------------------------------------------------
-- Invoices
-- ---------------------------------------------------------------------------
CREATE TABLE invoices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations (id),
    property_id     UUID NOT NULL REFERENCES properties (id),
    lease_id        UUID REFERENCES leases (id),
    room_id         UUID REFERENCES rooms (id),
    tenant_id       UUID REFERENCES tenants (id),
    invoice_number  TEXT NOT NULL,
    status          invoice_status NOT NULL DEFAULT 'DRAFT',
    currency        CHAR(3) NOT NULL DEFAULT 'THB',
    subtotal_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(12, 2) NOT NULL DEFAULT 0,
    amount_paid     NUMERIC(12, 2) NOT NULL DEFAULT 0,
    due_date        DATE,
    issued_at       TIMESTAMPTZ,
    paid_at         TIMESTAMPTZ,
    voided_at       TIMESTAMPTZ,
    written_off_at  TIMESTAMPTZ,
    notes           TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT invoices_invoice_number_not_empty CHECK (length(trim(invoice_number)) > 0),
    CONSTRAINT invoices_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT invoices_amounts_non_negative CHECK (
        subtotal_amount >= 0
        AND tax_amount >= 0
        AND total_amount >= 0
        AND amount_paid >= 0
    ),
    CONSTRAINT invoices_amount_paid_lte_total CHECK (amount_paid <= total_amount),
    CONSTRAINT invoices_issued_timestamp CHECK (
        status = 'DRAFT' OR issued_at IS NOT NULL
    ),
    CONSTRAINT invoices_paid_consistency CHECK (
        status <> 'PAID' OR (amount_paid = total_amount AND paid_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX invoices_org_invoice_number_active_uidx
    ON invoices (organization_id, invoice_number)
    WHERE deleted_at IS NULL;

CREATE INDEX invoices_property_id_idx ON invoices (property_id);
CREATE INDEX invoices_lease_id_idx ON invoices (lease_id);
CREATE INDEX invoices_status_due_date_idx ON invoices (status, due_date);

CREATE TRIGGER invoices_set_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Invoice line items
-- ---------------------------------------------------------------------------
CREATE TABLE invoice_lines (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id      UUID NOT NULL REFERENCES invoices (id),
    line_number     INTEGER NOT NULL,
    description     TEXT NOT NULL,
    quantity        NUMERIC(10, 2) NOT NULL DEFAULT 1,
    unit_price      NUMERIC(12, 2) NOT NULL,
    line_total      NUMERIC(12, 2) NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT invoice_lines_unique_line_number UNIQUE (invoice_id, line_number),
    CONSTRAINT invoice_lines_description_not_empty CHECK (length(trim(description)) > 0),
    CONSTRAINT invoice_lines_quantity_positive CHECK (quantity > 0),
    CONSTRAINT invoice_lines_amounts_non_negative CHECK (
        unit_price >= 0 AND line_total >= 0
    )
);

CREATE INDEX invoice_lines_invoice_id_idx ON invoice_lines (invoice_id);

CREATE TRIGGER invoice_lines_set_updated_at
    BEFORE UPDATE ON invoice_lines
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Payments (Opn / Omise — PromptPay Dynamic QR)
-- ---------------------------------------------------------------------------
CREATE TABLE payments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id         UUID NOT NULL REFERENCES organizations (id),
    invoice_id              UUID NOT NULL REFERENCES invoices (id),
    status                  payment_status NOT NULL DEFAULT 'PENDING',
    provider                payment_provider NOT NULL,
    amount                  NUMERIC(12, 2) NOT NULL,
    currency                CHAR(3) NOT NULL DEFAULT 'THB',
    idempotency_key         TEXT NOT NULL,
    provider_charge_id      TEXT,
    provider_transaction_id TEXT,
    qr_payload              JSONB,
    provider_metadata       JSONB NOT NULL DEFAULT '{}'::JSONB,
    expires_at              TIMESTAMPTZ,
    succeeded_at            TIMESTAMPTZ,
    failed_at               TIMESTAMPTZ,
    refunded_at             TIMESTAMPTZ,
    failure_reason          TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ,

    CONSTRAINT payments_amount_positive CHECK (amount > 0),
    CONSTRAINT payments_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT payments_idempotency_key_not_empty CHECK (length(trim(idempotency_key)) > 0),
    CONSTRAINT payments_succeeded_timestamp CHECK (
        status <> 'SUCCEEDED' OR succeeded_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX payments_idempotency_key_uidx
    ON payments (idempotency_key);

CREATE UNIQUE INDEX payments_provider_charge_id_uidx
    ON payments (provider, provider_charge_id)
    WHERE provider_charge_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX payments_invoice_id_idx ON payments (invoice_id);
CREATE INDEX payments_status_idx ON payments (status);

CREATE TRIGGER payments_set_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE payments IS 'Payment attempts per invoice; idempotency_key prevents duplicate charges.';

-- ---------------------------------------------------------------------------
-- Invoice allocations (payment → invoice settlement)
-- ---------------------------------------------------------------------------
CREATE TABLE invoice_allocations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id      UUID NOT NULL REFERENCES payments (id),
    invoice_id      UUID NOT NULL REFERENCES invoices (id),
    amount          NUMERIC(12, 2) NOT NULL,
    allocated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,

    CONSTRAINT invoice_allocations_amount_positive CHECK (amount > 0),
    CONSTRAINT invoice_allocations_unique_payment_invoice UNIQUE (payment_id, invoice_id)
);

CREATE INDEX invoice_allocations_invoice_id_idx ON invoice_allocations (invoice_id);

-- ---------------------------------------------------------------------------
-- Payment webhook events (async reconciliation + idempotency)
-- ---------------------------------------------------------------------------
CREATE TABLE payment_webhook_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id         UUID REFERENCES organizations (id),
    payment_id              UUID REFERENCES payments (id),
    provider                payment_provider NOT NULL,
    provider_event_id       TEXT NOT NULL,
    provider_transaction_id TEXT,
    event_type              TEXT NOT NULL,
    processing_status       webhook_event_status NOT NULL DEFAULT 'RECEIVED',
    signature_verified      BOOLEAN NOT NULL DEFAULT FALSE,
    raw_payload             JSONB NOT NULL,
    error_message           TEXT,
    received_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT payment_webhook_events_provider_event_id_not_empty
        CHECK (length(trim(provider_event_id)) > 0),
    CONSTRAINT payment_webhook_events_event_type_not_empty
        CHECK (length(trim(event_type)) > 0)
);

CREATE UNIQUE INDEX payment_webhook_events_provider_event_id_uidx
    ON payment_webhook_events (provider, provider_event_id);

CREATE INDEX payment_webhook_events_payment_id_idx ON payment_webhook_events (payment_id);
CREATE INDEX payment_webhook_events_processing_status_idx
    ON payment_webhook_events (processing_status)
    WHERE processing_status IN ('RECEIVED', 'PROCESSING');

CREATE TRIGGER payment_webhook_events_set_updated_at
    BEFORE UPDATE ON payment_webhook_events
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE payment_webhook_events IS 'Immutable provider webhook inbox; provider_event_id guarantees idempotent processing.';

-- ---------------------------------------------------------------------------
-- Payment logs (operational trace — complements webhook_events)
-- ---------------------------------------------------------------------------
CREATE TABLE payment_logs (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id              UUID NOT NULL REFERENCES payments (id),
    invoice_id              UUID NOT NULL REFERENCES invoices (id),
    organization_id         UUID NOT NULL REFERENCES organizations (id),
    log_type                TEXT NOT NULL,
    from_status             payment_status,
    to_status               payment_status,
    provider                payment_provider,
    provider_event_id       TEXT,
    provider_transaction_id TEXT,
    idempotency_key         TEXT,
    amount                  NUMERIC(12, 2),
    message                 TEXT,
    metadata                JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT payment_logs_log_type_not_empty CHECK (length(trim(log_type)) > 0)
);

CREATE INDEX payment_logs_payment_id_idx ON payment_logs (payment_id);
CREATE INDEX payment_logs_invoice_id_idx ON payment_logs (invoice_id);
CREATE INDEX payment_logs_provider_event_id_idx
    ON payment_logs (provider_event_id)
    WHERE provider_event_id IS NOT NULL;
CREATE INDEX payment_logs_occurred_at_idx ON payment_logs (occurred_at DESC);

COMMENT ON TABLE payment_logs IS 'Append-only payment lifecycle trace for ops/debug; webhook handler writes here.';

-- ---------------------------------------------------------------------------
-- Maintenance tickets
-- ---------------------------------------------------------------------------
CREATE TABLE maintenance_tickets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations (id),
    property_id     UUID NOT NULL REFERENCES properties (id),
    room_id         UUID REFERENCES rooms (id),
    ticket_number   TEXT NOT NULL,
    status          maintenance_status NOT NULL DEFAULT 'REPORTED',
    priority        maintenance_priority NOT NULL DEFAULT 'MEDIUM',
    title           TEXT NOT NULL,
    description     TEXT,
    reported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_at    TIMESTAMPTZ,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    assigned_to     UUID REFERENCES users (id),
    reported_by     UUID REFERENCES users (id),
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT maintenance_tickets_ticket_number_not_empty
        CHECK (length(trim(ticket_number)) > 0),
    CONSTRAINT maintenance_tickets_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT maintenance_tickets_completed_timestamp CHECK (
        status <> 'COMPLETED' OR completed_at IS NOT NULL
    ),
    CONSTRAINT maintenance_tickets_cancelled_timestamp CHECK (
        status <> 'CANCELLED' OR cancelled_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX maintenance_tickets_org_ticket_number_active_uidx
    ON maintenance_tickets (organization_id, ticket_number)
    WHERE deleted_at IS NULL;

CREATE INDEX maintenance_tickets_property_status_idx
    ON maintenance_tickets (property_id, status);
CREATE INDEX maintenance_tickets_room_id_idx ON maintenance_tickets (room_id);

CREATE TRIGGER maintenance_tickets_set_updated_at
    BEFORE UPDATE ON maintenance_tickets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Audit logs (centralized immutable state-change trail)
-- ---------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations (id),
    property_id     UUID REFERENCES properties (id),
    entity_type     TEXT NOT NULL,
    entity_id       UUID NOT NULL,
    action          TEXT NOT NULL DEFAULT 'state.transition',
    from_state      TEXT,
    to_state        TEXT,
    actor_id        UUID REFERENCES users (id),
    actor_type      actor_type NOT NULL,
    correlation_id  TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT audit_logs_entity_type_not_empty CHECK (length(trim(entity_type)) > 0),
    CONSTRAINT audit_logs_action_not_empty CHECK (length(trim(action)) > 0),
    CONSTRAINT audit_logs_actor_id_required_for_user CHECK (
        actor_type <> 'user' OR actor_id IS NOT NULL
    )
);

CREATE INDEX audit_logs_entity_idx ON audit_logs (entity_type, entity_id);
CREATE INDEX audit_logs_property_occurred_idx ON audit_logs (property_id, occurred_at DESC);
CREATE INDEX audit_logs_organization_occurred_idx ON audit_logs (organization_id, occurred_at DESC);
CREATE INDEX audit_logs_correlation_id_idx ON audit_logs (correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX audit_logs_actor_idx ON audit_logs (actor_id) WHERE actor_id IS NOT NULL;

COMMENT ON TABLE audit_logs IS 'WHO changed WHAT state WHEN — append-only; no UPDATE/DELETE in application layer.';

-- ---------------------------------------------------------------------------
-- Referential integrity: scope leases/invoices to same organization as property
-- (enforced via application; optional future triggers omitted for clarity)
-- ---------------------------------------------------------------------------

COMMIT;

-- =============================================================================
-- Optional seed (Property A & B) — uncomment to load reference data
-- =============================================================================
/*
BEGIN;

INSERT INTO organizations (id, code, name)
VALUES ('00000000-0000-4000-8000-000000000001', 'CENTERIZE', 'Centerize Operations');

INSERT INTO properties (id, organization_id, code, name, address, location_notes, grid_rows, grid_columns)
VALUES
    ('00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000001',
     'PROPERTY_A', 'Property A', NULL, NULL, 2, 7),
    ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001',
     'PROPERTY_B', 'Property B', NULL, 'Near Aranyaprathet District Office (อำเภออรัญประเทศ)', 2, 4);

COMMIT;
*/
