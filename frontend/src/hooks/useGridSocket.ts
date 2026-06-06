'use client';

import { useEffect } from 'react';
import { getGridSocket } from '@/lib/socket';
import type { RoomStateChangedEvent } from '@/types/pms';

export function useGridSocket(
  propertyId: string,
  onRoomStateChanged: (event: RoomStateChangedEvent) => void,
) {
  useEffect(() => {
    const socket = getGridSocket();

    if (!socket.connected) socket.connect();

    socket.emit('property.subscribe', { propertyId });

    const handler = (event: RoomStateChangedEvent) => {
      if (event.propertyId === propertyId) onRoomStateChanged(event);
    };

    socket.on('room.state_changed', handler);

    return () => {
      socket.off('room.state_changed', handler);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [propertyId]);
}
