import { Body, Controller, Headers, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { WebhookService } from './webhook.service';

@Controller('webhooks')
export class WebhookController {
  constructor(private readonly webhookService: WebhookService) {}

  @Post(':provider')
  @HttpCode(HttpStatus.ACCEPTED)
  ingest(
    @Param('provider') provider: 'omise' | 'opn',
    @Headers('x-signature') signature: string | undefined,
    @Body() payload: Record<string, unknown>,
  ) {
    return this.webhookService.ingest(provider, payload, signature);
  }
}
