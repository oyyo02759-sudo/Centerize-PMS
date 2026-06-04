import { Logger } from '@nestjs/common';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PropertyService } from '../property/property.service';

@WebSocketGateway({
  namespace: '/grid',
  cors: { origin: '*' },
})
export class GridGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(GridGateway.name);

  constructor(private readonly propertyService: PropertyService) {}

  handleConnection(client: Socket) {
    this.logger.debug(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.debug(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('property.subscribe')
  async handleSubscribe(
    client: Socket,
    payload: { propertyId: string },
  ): Promise<{ channel: string }> {
    const channel = `property:${payload.propertyId}:grid`;
    await client.join(channel);

    try {
      const rooms = await this.propertyService.getGridRoomCells(
        payload.propertyId,
      );
      this.emitGridSnapshot(payload.propertyId, rooms);
    } catch (error) {
      this.logger.warn(
        `Grid snapshot skipped for property ${payload.propertyId}: ${String(error)}`,
      );
    }

    return { channel };
  }

  emitRoomStateChanged(
    propertyId: string,
    data: { roomId: string; from: string; to: string },
  ): void {
    this.server
      .to(`property:${propertyId}:grid`)
      .emit('room.state_changed', { propertyId, ...data });
  }

  emitGridSnapshot(propertyId: string, rooms: unknown[]): void {
    this.server
      .to(`property:${propertyId}:grid`)
      .emit('grid.snapshot', { propertyId, rooms });
  }
}
