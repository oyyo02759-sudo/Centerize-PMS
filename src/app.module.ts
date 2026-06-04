import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { BillingModule } from './modules/billing/billing.module';
import { HealthModule } from './modules/health/health.module';
import { PropertyModule } from './modules/property/property.module';
import { WebhookModule } from './modules/webhook/webhook.module';
import { WebsocketModule } from './modules/websocket/websocket.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    PropertyModule,
    BillingModule,
    WebhookModule,
    WebsocketModule,
  ],
})
export class AppModule {}
