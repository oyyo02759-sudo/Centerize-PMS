import { Module } from '@nestjs/common';
import { PropertyModule } from '../property/property.module';
import { GridGateway } from './grid.gateway';

@Module({
  imports: [PropertyModule],
  providers: [GridGateway],
  exports: [GridGateway],
})
export class WebsocketModule {}
