import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { timingSafeEqual, createHmac } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { GridGateway } from '../websocket/grid.gateway';

export type WebhookProvider = 'omise' | 'opn';

/**
 * 10-step idempotent payment webhook pipeline:
 * 1. receive  2. verify signature  3. persist raw event
 * 4. idempotency check  5. enqueue  6. load payment
 * 7. reconcile payment  8. allocate invoice  9. audit log  10. broadcast grid
 */
@Injectable()
export class WebhookService {
  private readonly logger = new Logger(WebhookService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly gridGateway: GridGateway,
  ) {}

  // ─── Step 1: Entry point ───────────────────────────────────────────────────

  async ingest(
    provider: WebhookProvider,
    payload: Record<string, unknown>,
    rawBody: Buffer,
    signature?: string,
  ): Promise<{ eventId: string; status: 'RECEIVED' }> {
    const eventId = this.extractEventId(provider, payload);
    const eventKey = typeof payload.key === 'string' ? payload.key : 'unknown';
    this.logger.log(`[1] Received provider=${provider} eventId=${eventId} key=${eventKey}`);

    // Step 2: verify HMAC signature
    await this.verifySignature(provider, signature, rawBody);

    // Step 3: persist raw event (returns null if duplicate)
    const webhookEvent = await this.persistRawEvent(provider, eventId, eventKey, payload);

    // Step 4: idempotency guard
    if (webhookEvent === null) {
      this.logger.log(`[4] Duplicate dropped provider=${provider} eventId=${eventId}`);
      return { eventId, status: 'RECEIVED' };
    }

    // Steps 5–10: fire-and-forget reconciliation
    this.runReconciliation(provider, eventId, eventKey, payload, webhookEvent.id).catch(
      (err: unknown) =>
        this.logger.error(`Reconciliation failed eventId=${eventId}: ${String(err)}`),
    );

    return { eventId, status: 'RECEIVED' };
  }

  // ─── Step 2: HMAC-SHA256 signature verification ────────────────────────────

  private async verifySignature(
    provider: WebhookProvider,
    signature: string | undefined,
    rawBody: Buffer,
  ): Promise<void> {
    const secret = this.config.get<string>('OMISE_WEBHOOK_SECRET');
    if (!secret) return; // dev mode: skip when secret not configured

    if (!signature) {
      throw new UnauthorizedException('Missing webhook signature');
    }

    const hmac = createHmac('sha256', secret).update(rawBody).digest('hex');
    const sigBuf = Buffer.from(signature, 'hex');
    const hmacBuf = Buffer.from(hmac, 'hex');
    const valid =
      sigBuf.length === hmacBuf.length && timingSafeEqual(hmacBuf, sigBuf);

    if (!valid) {
      this.logger.warn(`[2] Signature mismatch provider=${provider}`);
      throw new UnauthorizedException('Invalid webhook signature');
    }
    this.logger.debug('[2] Signature verified');
  }

  // ─── Step 3: Persist raw event (upsert-safe via unique constraint) ─────────

  private async persistRawEvent(
    provider: WebhookProvider,
    eventId: string,
    eventKey: string,
    payload: Record<string, unknown>,
  ): Promise<{ id: string } | null> {
    const data = payload.data as Record<string, unknown> | undefined;
    const providerTransactionId =
      typeof data?.id === 'string' ? data.id : undefined;

    try {
      const record = await this.prisma.paymentWebhookEvent.create({
        data: {
          provider,
          providerEventId: eventId,
          providerTransactionId,
          eventType: eventKey,
          processingStatus: 'RECEIVED',
          signatureVerified: true,
          rawPayload: payload as Prisma.InputJsonObject,
        },
        select: { id: true },
      });
      this.logger.debug(`[3] Event persisted id=${record.id}`);
      return record;
    } catch (err: unknown) {
      if (err instanceof Error && err.message.includes('Unique constraint')) {
        this.logger.debug(`[3] Already persisted provider=${provider} eventId=${eventId}`);
        return null;
      }
      throw err;
    }
  }

  // ─── Steps 5–10: Async reconciliation pipeline ────────────────────────────

  private async runReconciliation(
    provider: WebhookProvider,
    eventId: string,
    eventKey: string,
    payload: Record<string, unknown>,
    webhookDbId: string,
  ): Promise<void> {
    this.logger.debug(`[5] Reconciling provider=${provider} eventId=${eventId}`);

    try {
      await this.reconcile(provider, eventKey, payload, webhookDbId);
    } catch (err) {
      await this.prisma.paymentWebhookEvent.update({
        where: { id: webhookDbId },
        data: { processingStatus: 'FAILED', errorMessage: String(err), processedAt: new Date() },
      });
      throw err;
    }
  }

  private async reconcile(
    provider: WebhookProvider,
    eventKey: string,
    payload: Record<string, unknown>,
    webhookDbId: string,
  ): Promise<void> {
    // Step 4 (final): guard against re-entry
    const existing = await this.prisma.paymentWebhookEvent.findUnique({
      where: { id: webhookDbId },
      select: { processingStatus: true },
    });
    if (existing?.processingStatus === 'PROCESSED') {
      this.logger.log(`[4] Already processed id=${webhookDbId}`);
      return;
    }
    await this.prisma.paymentWebhookEvent.update({
      where: { id: webhookDbId },
      data: { processingStatus: 'PROCESSING' },
    });

    const data = payload.data as Record<string, unknown> | undefined;
    const isSuccessfulCharge =
      (eventKey === 'charge.complete' || eventKey === 'charge.update') &&
      data?.status === 'successful';

    if (!isSuccessfulCharge) {
      await this.prisma.paymentWebhookEvent.update({
        where: { id: webhookDbId },
        data: { processingStatus: 'PROCESSED', processedAt: new Date() },
      });
      this.logger.debug(`[7] Non-payment event acknowledged key=${eventKey}`);
      return;
    }

    const providerChargeId = typeof data?.id === 'string' ? data.id : null;
    const providerTransactionId =
      typeof data?.transaction === 'string' ? data.transaction : null;

    // Step 6: load payment by provider charge ID
    const payment = providerChargeId
      ? await this.prisma.payment.findFirst({
          where: { providerChargeId, deletedAt: null },
        })
      : null;

    if (!payment) {
      this.logger.warn(`[6] No payment found providerChargeId=${providerChargeId}`);
      await this.prisma.paymentWebhookEvent.update({
        where: { id: webhookDbId },
        data: { processingStatus: 'PROCESSED', processedAt: new Date() },
      });
      return;
    }

    const now = new Date();

    // Steps 7 & 8: update payment + invoice + allocation atomically
    const invoice = await this.prisma.$transaction(async (tx) => {
      // Step 7: reconcile payment → SUCCEEDED
      await tx.payment.update({
        where: { id: payment.id },
        data: { status: 'SUCCEEDED', providerTransactionId, succeededAt: now },
      });

      // Step 8: transition invoice → PAID (ชำระเงินแล้ว)
      const inv = await tx.invoice.update({
        where: { id: payment.invoiceId },
        data: { status: 'PAID', paidAt: now, amountPaid: payment.amount },
        select: {
          id: true,
          propertyId: true,
          roomId: true,
          organizationId: true,
          status: true,
        },
      });

      // Step 8b: allocate payment to invoice
      await tx.invoiceAllocation.upsert({
        where: { paymentId_invoiceId: { paymentId: payment.id, invoiceId: inv.id } },
        create: {
          paymentId: payment.id,
          invoiceId: inv.id,
          amount: payment.amount,
          metadata: { source: 'webhook', provider },
        },
        update: {},
      });

      // Mark webhook event as linked + PROCESSED
      await tx.paymentWebhookEvent.update({
        where: { id: webhookDbId },
        data: {
          paymentId: payment.id,
          organizationId: inv.organizationId,
          processingStatus: 'PROCESSED',
          processedAt: now,
        },
      });

      return inv;
    });

    // Step 9: audit log — invoice state transition → PAID
    await this.prisma.auditLog.create({
      data: {
        organizationId: invoice.organizationId,
        propertyId: invoice.propertyId,
        entityType: 'invoice',
        entityId: invoice.id,
        action: 'state.transition',
        fromState: 'ISSUED',
        toState: 'PAID',
        actorType: 'webhook',
        correlationId: webhookDbId,
        metadata: {
          provider,
          providerChargeId,
          invoiceStatusLabel: 'ชำระเงินแล้ว',
        },
      },
    });

    this.logger.log(
      `[9] Invoice ${invoice.id} → PAID (ชำระเงินแล้ว) via ${provider} charge=${providerChargeId}`,
    );

    // Step 10: broadcast grid update to connected frontend clients
    if (invoice.propertyId) {
      this.gridGateway.emitRoomStateChanged(invoice.propertyId, {
        roomId: invoice.roomId ?? '',
        from: 'OCCUPIED',
        to: 'OCCUPIED',
      });
      this.logger.debug(`[10] Grid broadcast propertyId=${invoice.propertyId}`);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private extractEventId(
    provider: WebhookProvider,
    payload: Record<string, unknown>,
  ): string {
    if ((provider === 'omise' || provider === 'opn') && typeof payload.id === 'string') {
      return payload.id;
    }
    if (typeof payload.event_id === 'string') return payload.event_id;
    return `unknown-${Date.now()}`;
  }
}
