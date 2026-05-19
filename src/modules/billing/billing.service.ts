import { Injectable, NotFoundException } from '@nestjs/common';

export type PaymentProvider = 'omise' | 'opn';

@Injectable()
export class BillingService {
  async getInvoice(id: string): Promise<unknown> {
    const invoice = await this.findInvoiceById(id);
    if (!invoice) {
      throw new NotFoundException(`Invoice ${id} not found`);
    }
    return invoice;
  }

  async issueInvoice(id: string): Promise<unknown> {
    return { invoiceId: id, status: 'ISSUED' };
  }

  async createPromptPayQr(invoiceId: string): Promise<{
    invoiceId: string;
    provider: PaymentProvider;
    qrPayload: Record<string, unknown>;
    idempotencyKey: string;
  }> {
    return {
      invoiceId,
      provider: 'omise',
      qrPayload: {},
      idempotencyKey: `pay-idem-${invoiceId}`,
    };
  }

  async handleProviderWebhook(
    provider: PaymentProvider,
    _payload: Record<string, unknown>,
  ): Promise<{ accepted: boolean; provider: PaymentProvider }> {
    return { accepted: true, provider };
  }

  private async findInvoiceById(_id: string): Promise<unknown | null> {
    return null;
  }
}
