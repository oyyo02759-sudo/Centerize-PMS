import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BillingModule } from './modules/billing/billing.module';
import { PropertyModule } from './modules/property/property.module';
import { WebhookModule } from './modules/webhook/webhook.module';
import { WebsocketModule } from './modules/websocket/websocket.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: config.get<number>('DB_PORT', 5432),
        username: config.get<string>('DB_USER', 'postgres'),
        password: config.get<string>('DB_PASSWORD', 'postgres'),
        database: config.get<string>('DB_NAME', 'centerize_pms'),
        autoLoadEntities: true,
        synchronize: false,
      }),
    }),
    PropertyModule,
    BillingModule,
    WebhookModule,
    WebsocketModule,
  ],
})
export class AppModule {}
