import { Injectable, NotFoundException } from '@nestjs/common';
import { Invoice, InvoiceLine, Prisma } from '@prisma/client';
import { decimalToNumber, jsonRecord } from '../../common/serialize';
import { PrismaService } from '../../prisma/prisma.service';

export interface MeterReading {
  utilityType: 'electricity' | 'water';
  previousReading: number;
  currentReading: number;
  ratePerUnit: number;
}

export interface GenerateInvoiceInput {
  leaseId: string;
  billingPeriod: string;
  dueDate: string;
  meterReadings: MeterReading[];
}

export type PaymentProvider = 'omise' | 'opn';

export interface InvoiceLineDto {
  id: string;
  lineNumber: number;
  description: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
  metadata: Record<string, unknown>;
}

export interface InvoiceDetailDto {
  id: string;
  organizationId: string;
  propertyId: string;
  leaseId: string | null;
  roomId: string | null;
  tenantId: string | null;
  invoiceNumber: string;
  status: string;
  currency: string;
  subtotalAmount: number;
  taxAmount: number;
  totalAmount: number;
  amountPaid: number;
  dueDate: string | null;
  issuedAt: string | null;
  paidAt: string | null;
  notes: string | null;
  metadata: Record<string, unknown>;
  lines: InvoiceLineDto[];
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class BillingService {
  constructor(private readonly prisma: PrismaService) {}

  async getInvoice(id: string): Promise<InvoiceDetailDto> {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id, deletedAt: null },
      include: {
        lines: { orderBy: { lineNumber: 'asc' } },
      },
    });
    if (!invoice) {
      throw new NotFoundException(`Invoice ${id} not found`);
    }
    return this.toInvoiceDetail(invoice);
  }

  async issueInvoice(id: string): Promise<{ invoiceId: string; status: string }> {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id, deletedAt: null },
    });
    if (!invoice) {
      throw new NotFoundException(`Invoice ${id} not found`);
    }
    if (invoice.status !== 'DRAFT') {
      return { invoiceId: id, status: invoice.status };
    }

    const updated = await this.prisma.invoice.update({
      where: { id },
      data: {
        status: 'ISSUED',
        issuedAt: new Date(),
      },
    });

    return { invoiceId: id, status: updated.status };
  }

  async createPromptPayQr(invoiceId: string): Promise<{
    invoiceId: string;
    provider: PaymentProvider;
    qrPayload: Record<string, unknown>;
    idempotencyKey: string;
  }> {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: invoiceId, deletedAt: null },
    });
    if (!invoice) {
      throw new NotFoundException(`Invoice ${invoiceId} not found`);
    }

    const idempotencyKey = `pay-idem-${invoiceId}`;
    const existing = await this.prisma.payment.findFirst({
      where: { invoiceId, idempotencyKey, deletedAt: null },
    });

    if (existing?.qrPayload) {
      return {
        invoiceId,
        provider: existing.provider as PaymentProvider,
        qrPayload: jsonRecord(existing.qrPayload),
        idempotencyKey,
      };
    }

    const qrPayload = {
      provider: 'omise',
      method: 'promptpay',
      amount: decimalToNumber(invoice.totalAmount),
      currency: invoice.currency.trim(),
      invoiceNumber: invoice.invoiceNumber,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
    };

    if (!existing) {
      await this.prisma.payment.create({
        data: {
          organizationId: invoice.organizationId,
          invoiceId,
          provider: 'omise',
          amount: invoice.totalAmount,
          currency: invoice.currency,
          idempotencyKey,
          qrPayload,
          expiresAt: new Date(Date.now() + 15 * 60 * 1000),
        },
      });
    }

    return {
      invoiceId,
      provider: 'omise',
      qrPayload,
      idempotencyKey,
    };
  }

  async generateInvoice(input: GenerateInvoiceInput): Promise<InvoiceDetailDto> {
    const { leaseId, billingPeriod, dueDate, meterReadings } = input;

    const lease = await this.prisma.lease.findFirst({
      where: { id: leaseId, deletedAt: null, status: { in: ['ACTIVE', 'NOTICE_GIVEN'] } },
    });
    if (!lease) {
      throw new NotFoundException(`Active lease ${leaseId} not found`);
    }

    const invoiceNumber = `INV-${billingPeriod}-${lease.id.slice(0, 8).toUpperCase()}`;

    const UTILITY_LABEL: Record<string, string> = {
      electricity: 'ค่าไฟฟ้า',
      water: 'ค่าน้ำประปา',
    };

    type RawLine = {
      description: string;
      quantity: number;
      unitPrice: number;
      lineTotal: number;
      metadata: Record<string, unknown>;
    };

    const lines: RawLine[] = [];

    const rentAmount = decimalToNumber(lease.monthlyRent);
    lines.push({
      description: 'ค่าเช่า',
      quantity: 1,
      unitPrice: rentAmount,
      lineTotal: rentAmount,
      metadata: { line_type: 'rent', billing_period: billingPeriod },
    });

    for (const reading of meterReadings) {
      const units = reading.currentReading - reading.previousReading;
      const lineTotal = units * reading.ratePerUnit;
      lines.push({
        description: UTILITY_LABEL[reading.utilityType] ?? reading.utilityType,
        quantity: units,
        unitPrice: reading.ratePerUnit,
        lineTotal,
        metadata: {
          line_type: 'utility',
          utility_type: reading.utilityType,
          previous_reading: reading.previousReading,
          current_reading: reading.currentReading,
          units,
          rate_per_unit: reading.ratePerUnit,
        },
      });
    }

    const subtotal = lines.reduce((sum, l) => sum + l.lineTotal, 0);

    const invoice = await this.prisma.$transaction(async (tx) => {
      const inv = await tx.invoice.create({
        data: {
          organizationId: lease.organizationId,
          propertyId: lease.propertyId,
          leaseId: lease.id,
          roomId: lease.roomId,
          tenantId: lease.primaryTenantId,
          invoiceNumber,
          status: 'DRAFT',
          currency: lease.currency,
          subtotalAmount: subtotal,
          taxAmount: 0,
          totalAmount: subtotal,
          amountPaid: 0,
          dueDate: new Date(dueDate),
          metadata: { billing_period: billingPeriod },
        },
      });

      await tx.invoiceLine.createMany({
        data: lines.map((line, i) => ({
          invoiceId: inv.id,
          lineNumber: i + 1,
          description: line.description,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          lineTotal: line.lineTotal,
          metadata: line.metadata as Prisma.InputJsonObject,
        })),
      });

      return tx.invoice.findFirstOrThrow({
        where: { id: inv.id },
        include: { lines: { orderBy: { lineNumber: 'asc' } } },
      });
    });

    return this.toInvoiceDetail(invoice);
  }

  async handleProviderWebhook(
    provider: PaymentProvider,
    _payload: Record<string, unknown>,
  ): Promise<{ accepted: boolean; provider: PaymentProvider }> {
    return { accepted: true, provider };
  }

  private toInvoiceDetail(
    invoice: Invoice & { lines: InvoiceLine[] },
  ): InvoiceDetailDto {
    return {
      id: invoice.id,
      organizationId: invoice.organizationId,
      propertyId: invoice.propertyId,
      leaseId: invoice.leaseId,
      roomId: invoice.roomId,
      tenantId: invoice.tenantId,
      invoiceNumber: invoice.invoiceNumber,
      status: invoice.status,
      currency: invoice.currency.trim(),
      subtotalAmount: decimalToNumber(invoice.subtotalAmount),
      taxAmount: decimalToNumber(invoice.taxAmount),
      totalAmount: decimalToNumber(invoice.totalAmount),
      amountPaid: decimalToNumber(invoice.amountPaid),
      dueDate: invoice.dueDate?.toISOString().slice(0, 10) ?? null,
      issuedAt: invoice.issuedAt?.toISOString() ?? null,
      paidAt: invoice.paidAt?.toISOString() ?? null,
      notes: invoice.notes,
      metadata: jsonRecord(invoice.metadata),
      lines: invoice.lines.map((line) => ({
        id: line.id,
        lineNumber: line.lineNumber,
        description: line.description,
        quantity: decimalToNumber(line.quantity),
        unitPrice: decimalToNumber(line.unitPrice),
        lineTotal: decimalToNumber(line.lineTotal),
        metadata: jsonRecord(line.metadata),
      })),
      createdAt: invoice.createdAt.toISOString(),
      updatedAt: invoice.updatedAt.toISOString(),
    };
  }
}
