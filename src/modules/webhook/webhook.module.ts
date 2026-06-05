import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { WebsocketModule } from '../websocket/websocket.module';
import { WebhookController } from './webhook.controller';
import { WebhookService } from './webhook.service';

@Module({
  imports: [BillingModule, WebsocketModule],
  controllers: [WebhookController],
  providers: [WebhookService],
  exports: [WebhookService],
})
export class WebhookModule {}
