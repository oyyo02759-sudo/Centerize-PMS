import { Invoice, Lease, Property, Room, Tenant } from '@prisma/client';
import { jsonRecord } from '../../common/serialize';
import {
  GridBillingBadge,
  GridRoomCell,
  PropertyDetail,
  PropertyGridMatrix,
  PropertySummary,
  RoomStatus,
} from './property.types';

const ACTIVE_LEASE_STATUSES = ['ACTIVE', 'NOTICE_GIVEN'] as const;

const ROOM_STATUS_LABEL: Record<RoomStatus, string> = {
  VACANT: 'ห้องว่าง',
  OCCUPIED: 'มีผู้เช่า',
  RESERVED: 'จอง',
  MAINTENANCE: 'ซ่อมบำรุง',
  OUT_OF_SERVICE: 'ปิดใช้งาน',
};

export function toPropertySummary(property: Property): PropertySummary {
  return {
    id: property.id,
    code: property.code,
    name: property.name,
    gridRows: property.gridRows,
    gridColumns: property.gridColumns,
    locationNotes: property.locationNotes,
  };
}

export function toPropertyDetail(property: Property): PropertyDetail {
  return {
    ...toPropertySummary(property),
    organizationId: property.organizationId,
    address: property.address,
    metadata: jsonRecord(property.metadata),
    createdAt: property.createdAt.toISOString(),
    updatedAt: property.updatedAt.toISOString(),
  };
}

export function computeBillingBadge(
  invoices: Pick<Invoice, 'status'>[],
): GridBillingBadge {
  if (invoices.some((invoice) => invoice.status === 'OVERDUE')) {
    return 'OVERDUE';
  }
  if (invoices.some((invoice) => invoice.status === 'ISSUED')) {
    return 'DUE';
  }
  return 'NONE';
}

export function isActiveLease(lease: Pick<Lease, 'status'>): boolean {
  return ACTIVE_LEASE_STATUSES.includes(
    lease.status as (typeof ACTIVE_LEASE_STATUSES)[number],
  );
}

export function toGridRoomCell(
  room: Room,
  activeLease: (Lease & { primaryTenant: Tenant }) | null,
  leaseInvoices: Pick<Invoice, 'status'>[],
): GridRoomCell {
  return {
    id: room.id,
    roomNumber: room.roomNumber,
    gridPositionRow: room.gridPositionRow,
    gridPositionCol: room.gridPositionCol,
    status: room.status as RoomStatus,
    statusLabel: ROOM_STATUS_LABEL[room.status as RoomStatus],
    isActiveCell: room.isActiveCell,
    label: room.label,
    activeLeaseId: activeLease?.id ?? null,
    tenantDisplayName: activeLease?.primaryTenant.fullName ?? null,
    billingBadge: activeLease ? computeBillingBadge(leaseInvoices) : 'NONE',
    metadata: jsonRecord(room.metadata),
  };
}

export function toPropertyGridMatrix(
  property: Property,
  rooms: GridRoomCell[],
): PropertyGridMatrix {
  return {
    propertyId: property.id,
    code: property.code,
    name: property.name,
    gridRows: property.gridRows,
    gridColumns: property.gridColumns,
    rooms,
    generatedAt: new Date().toISOString(),
  };
}
