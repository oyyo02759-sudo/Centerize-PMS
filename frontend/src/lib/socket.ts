import { io, Socket } from 'socket.io-client';

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'http://localhost:3000';

let socket: Socket | null = null;

export function getGridSocket(): Socket {
  if (!socket) {
    socket = io(`${WS_URL}/grid`, {
      transports: ['websocket'],
      autoConnect: false,
    });
  }
  return socket;
}
