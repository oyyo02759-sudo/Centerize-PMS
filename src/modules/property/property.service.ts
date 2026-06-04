import { Injectable, NotFoundException } from '@nestjs/common';
import { Invoice, Lease, Tenant } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  computeBillingBadge,
  isActiveLease,
  toGridRoomCell,
  toPropertyDetail,
  toPropertyGridMatrix,
  toPropertySummary,
} from './property.mapper';
import {
  GridRoomCell,
  PropertyDetail,
  PropertyGridMatrix,
  PropertySummary,
} from './property.types';

type ActiveLeaseWithTenant = Lease & { primaryTenant: Tenant };

@Injectable()
export class PropertyService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<PropertySummary[]> {
    const properties = await this.prisma.property.findMany({
      where: { deletedAt: null },
      orderBy: { code: 'asc' },
    });
    return properties.map(toPropertySummary);
  }

  async findOne(id: string): Promise<PropertyDetail> {
    const property = await this.findPropertyOrThrow(id);
    return toPropertyDetail(property);
  }

  async getGridMatrix(propertyId: string): Promise<PropertyGridMatrix> {
    const property = await this.findPropertyOrThrow(propertyId);
    const rooms = await this.buildGridRoomCells(propertyId);
    return toPropertyGridMatrix(property, rooms);
  }

  async getGridRoomCells(propertyId: string): Promise<GridRoomCell[]> {
    await this.findPropertyOrThrow(propertyId);
    return this.buildGridRoomCells(propertyId);
  }

  private async findPropertyOrThrow(id: string) {
    const property = await this.prisma.property.findFirst({
      where: { id, deletedAt: null },
    });
    if (!property) {
      throw new NotFoundException(`Property ${id} not found`);
    }
    return property;
  }

  private async buildGridRoomCells(propertyId: string): Promise<GridRoomCell[]> {
    const rooms = await this.prisma.room.findMany({
      where: { propertyId, deletedAt: null },
      orderBy: [
        { gridPositionRow: 'asc' },
        { gridPositionCol: 'asc' },
        { roomNumber: 'asc' },
      ],
    });

    if (rooms.length === 0) {
      return [];
    }

    const roomIds = rooms.map((room) => room.id);

    const activeLeases = await this.prisma.lease.findMany({
      where: {
        propertyId,
        roomId: { in: roomIds },
        deletedAt: null,
        status: { in: ['ACTIVE', 'NOTICE_GIVEN'] },
      },
      include: { primaryTenant: true },
    });

    const leaseByRoomId = new Map<string, ActiveLeaseWithTenant>();
    for (const lease of activeLeases) {
      if (isActiveLease(lease)) {
        leaseByRoomId.set(lease.roomId, lease);
      }
    }

    const leaseIds = [...new Set(activeLeases.map((lease) => lease.id))];
    const invoicesByLeaseId = await this.loadOpenInvoicesByLeaseId(leaseIds);

    return rooms.map((room) => {
      const activeLease = leaseByRoomId.get(room.id) ?? null;
      const leaseInvoices = activeLease
        ? (invoicesByLeaseId.get(activeLease.id) ?? [])
        : [];
      return toGridRoomCell(room, activeLease, leaseInvoices);
    });
  }

  private async loadOpenInvoicesByLeaseId(
    leaseIds: string[],
  ): Promise<Map<string, Pick<Invoice, 'status'>[]>> {
    const result = new Map<string, Pick<Invoice, 'status'>[]>();
    if (leaseIds.length === 0) {
      return result;
    }

    const invoices = await this.prisma.invoice.findMany({
      where: {
        leaseId: { in: leaseIds },
        deletedAt: null,
        status: { in: ['OVERDUE', 'ISSUED', 'PARTIALLY_PAID'] },
      },
      select: { leaseId: true, status: true },
    });

    for (const invoice of invoices) {
      if (!invoice.leaseId) continue;
      const list = result.get(invoice.leaseId) ?? [];
      list.push(invoice);
      result.set(invoice.leaseId, list);
    }

    return result;
  }
}
