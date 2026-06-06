'use client';

import { useCallback } from 'react';
import { usePropertyGrid } from '@/hooks/usePropertyGrid';
import { useGridSocket } from '@/hooks/useGridSocket';
import { RoomCell } from '@/components/RoomCell';
import type { GridRoomCell, RoomStateChangedEvent } from '@/types/pms';

interface Props {
  propertyId: string;
}

export function PropertyGrid({ propertyId }: Props) {
  const { data, loading, error, updateRoom } = usePropertyGrid(propertyId);

  const handleRoomStateChanged = useCallback(
    (event: RoomStateChangedEvent) => {
      updateRoom(event.roomId, { status: event.to as GridRoomCell['status'] });
    },
    [updateRoom],
  );

  useGridSocket(propertyId, handleRoomStateChanged);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-48 text-gray-400 text-sm">
        กำลังโหลด…
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="flex items-center justify-center h-48 text-red-500 text-sm">
        โหลดข้อมูลไม่สำเร็จ: {error}
      </div>
    );
  }

  // Build a sparse map: "[row]-[col]" → GridRoomCell
  const cellMap = new Map<string, GridRoomCell>();
  for (const room of data.rooms) {
    cellMap.set(`${room.gridPositionRow}-${room.gridPositionCol}`, room);
  }

  return (
    <section className="space-y-4">
      <header className="flex items-baseline justify-between">
        <div>
          <h2 className="text-xl font-bold text-gray-900">{data.name}</h2>
          <p className="text-xs text-gray-400">{data.code} · {data.gridRows}×{data.gridColumns}</p>
        </div>
        <Legend />
      </header>

      {/* Dynamic grid — driven entirely by gridRows × gridColumns from API */}
      <div
        className="grid gap-2"
        style={{ gridTemplateColumns: `repeat(${data.gridColumns}, minmax(0, 1fr))` }}
      >
        {Array.from({ length: data.gridRows }, (_, row) =>
          Array.from({ length: data.gridColumns }, (_, col) => {
            const cell = cellMap.get(`${row}-${col}`);
            return cell ? (
              <RoomCell key={cell.id} cell={cell} />
            ) : (
              <div
                key={`empty-${row}-${col}`}
                className="rounded-lg border-2 border-dashed border-gray-200 min-h-[80px]"
              />
            );
          }),
        )}
      </div>
    </section>
  );
}

function Legend() {
  const items = [
    { color: 'bg-green-400', label: 'ห้องว่าง' },
    { color: 'bg-indigo-400', label: 'มีผู้เช่า - ชำระแล้ว' },
    { color: 'bg-yellow-400', label: 'มีผู้เช่า - รอชำระ' },
    { color: 'bg-red-400', label: 'มีผู้เช่า - ค้างชำระ' },
    { color: 'bg-amber-400', label: 'ซ่อมบำรุง' },
  ];
  return (
    <ul className="flex flex-wrap gap-3 text-[11px] text-gray-600">
      {items.map((item) => (
        <li key={item.label} className="flex items-center gap-1">
          <span className={`inline-block w-2.5 h-2.5 rounded-sm ${item.color}`} />
          {item.label}
        </li>
      ))}
    </ul>
  );
}
