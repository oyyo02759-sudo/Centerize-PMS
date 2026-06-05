export type RoomStatus =
  | 'VACANT'
  | 'RESERVED'
  | 'OCCUPIED'
  | 'MAINTENANCE'
  | 'OUT_OF_SERVICE';

export type GridBillingBadge = 'NONE' | 'OVERDUE' | 'DUE';

export interface PropertySummary {
  id: string;
  code: string;
  name: string;
  gridRows: number;
  gridColumns: number;
  locationNotes: string | null;
}

export interface PropertyDetail extends PropertySummary {
  organizationId: string;
  address: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface GridRoomCell {
  id: string;
  roomNumber: string;
  gridPositionRow: number;
  gridPositionCol: number;
  status: RoomStatus;
  statusLabel: string;
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
