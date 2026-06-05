import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  RawBodyRequest,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { WebhookService } from './webhook.service';

@Controller('webhooks')
export class WebhookController {
  constructor(private readonly webhookService: WebhookService) {}

  @Post(':provider')
  @HttpCode(HttpStatus.ACCEPTED)
  ingest(
    @Param('provider') provider: 'omise' | 'opn',
    @Headers('x-opn-signature') signature: string | undefined,
    @Body() payload: Record<string, unknown>,
    @Req() req: RawBodyRequest<Request>,
  ) {
    return this.webhookService.ingest(
      provider,
      payload,
      req.rawBody ?? Buffer.from(JSON.stringify(payload)),
      signature,
    );
  }
}
