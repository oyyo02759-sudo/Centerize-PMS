import { Injectable, Logger } from '@nestjs/common';

export type WebhookProvider = 'omise' | 'opn';

/**
 * 10-step idempotent payment webhook pipeline:
 * 1. receive  2. verify signature  3. persist raw event
 * 4. idempotency check  5. enqueue  6. load payment
 * 7. reconcile  8. allocate invoice  9. audit log  10. broadcast grid
 */
@Injectable()
export class WebhookService {
  private readonly logger = new Logger(WebhookService.name);

  async ingest(
    provider: WebhookProvider,
    payload: Record<string, unknown>,
    signature?: string,
  ): Promise<{ eventId: string; status: 'RECEIVED' }> {
    const eventId = this.extractEventId(provider, payload);
    this.logger.log(`Webhook received provider=${provider} eventId=${eventId}`);

    await this.verifySignature(provider, signature, payload);
    await this.persistRawEvent(provider, eventId, payload);
    await this.assertIdempotent(provider, eventId);
    await this.enqueueReconciliation(provider, eventId);

    return { eventId, status: 'RECEIVED' };
  }

  private extractEventId(
    provider: WebhookProvider,
    payload: Record<string, unknown>,
  ): string {
    if (provider === 'omise' && typeof payload.id === 'string') {
      return payload.id;
    }
    if (typeof payload.event_id === 'string') {
      return payload.event_id;
    }
    return `unknown-${Date.now()}`;
  }

  private async verifySignature(
    _provider: WebhookProvider,
    _signature: string | undefined,
    _payload: Record<string, unknown>,
  ): Promise<void> {
    // TODO: Opn/Omise HMAC verification
  }

  private async persistRawEvent(
    _provider: WebhookProvider,
    _eventId: string,
    _payload: Record<string, unknown>,
  ): Promise<void> {
    // TODO: INSERT payment_webhook_events
  }

  private async assertIdempotent(
    _provider: WebhookProvider,
    _eventId: string,
  ): Promise<void> {
    // TODO: unique provider_event_id guard
  }

  private async enqueueReconciliation(
    _provider: WebhookProvider,
    _eventId: string,
  ): Promise<void> {
    // TODO: async worker / outbox
  }
}
