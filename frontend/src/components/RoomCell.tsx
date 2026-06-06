'use client';

import type { GridRoomCell } from '@/types/pms';

interface CellTheme {
  wrapper: string;
  badge: string;
}

function resolveTheme(cell: GridRoomCell): CellTheme {
  if (!cell.isActiveCell) {
    return { wrapper: 'bg-gray-100 border-gray-200 opacity-40', badge: '' };
  }

  switch (cell.status) {
    case 'VACANT':
      return {
        wrapper: 'bg-green-50 border-green-400 hover:bg-green-100',
        badge: 'bg-green-100 text-green-800',
      };
    case 'OCCUPIED': {
      if (cell.billingBadge === 'OVERDUE') {
        return {
          wrapper: 'bg-red-50 border-red-400 hover:bg-red-100',
          badge: 'bg-red-100 text-red-800',
        };
      }
      if (cell.billingBadge === 'DUE') {
        return {
          wrapper: 'bg-yellow-50 border-yellow-400 hover:bg-yellow-100',
          badge: 'bg-yellow-100 text-yellow-800',
        };
      }
      return {
        wrapper: 'bg-indigo-50 border-indigo-400 hover:bg-indigo-100',
        badge: 'bg-indigo-100 text-indigo-800',
      };
    }
    case 'RESERVED':
      return {
        wrapper: 'bg-purple-50 border-purple-400 hover:bg-purple-100',
        badge: 'bg-purple-100 text-purple-800',
      };
    case 'MAINTENANCE':
      return {
        wrapper: 'bg-amber-50 border-amber-400 hover:bg-amber-100',
        badge: 'bg-amber-100 text-amber-800',
      };
    case 'OUT_OF_SERVICE':
      return {
        wrapper: 'bg-gray-100 border-gray-400',
        badge: 'bg-gray-200 text-gray-600',
      };
    default:
      return { wrapper: 'bg-white border-gray-300', badge: '' };
  }
}

function billingLabel(cell: GridRoomCell): string | null {
  if (cell.status !== 'OCCUPIED') return null;
  if (cell.billingBadge === 'OVERDUE') return 'ค้างชำระ';
  if (cell.billingBadge === 'DUE') return 'รอชำระ';
  return 'ชำระแล้ว';
}

interface Props {
  cell: GridRoomCell;
  onClick?: (cell: GridRoomCell) => void;
}

export function RoomCell({ cell, onClick }: Props) {
  const theme = resolveTheme(cell);
  const billing = billingLabel(cell);

  return (
    <button
      type="button"
      onClick={() => onClick?.(cell)}
      className={`
        relative flex flex-col justify-between rounded-lg border-2 p-2
        min-h-[80px] text-left transition-colors cursor-pointer
        ${theme.wrapper}
      `}
    >
      <div className="flex items-start justify-between gap-1">
        <span className="text-sm font-bold text-gray-800 leading-none">
          {cell.roomNumber}
        </span>
        {cell.label && (
          <span className="text-[10px] text-gray-500 leading-none">{cell.label}</span>
        )}
      </div>

      <div className="mt-1 space-y-1">
        <span className={`inline-block rounded px-1.5 py-0.5 text-[11px] font-medium ${theme.badge}`}>
          {cell.statusLabel}
        </span>

        {billing && (
          <span className={`block text-[10px] font-semibold ${theme.badge}`}>
            {billing}
          </span>
        )}

        {cell.tenantDisplayName && (
          <span className="block text-[10px] text-gray-600 truncate max-w-full">
            {cell.tenantDisplayName}
          </span>
        )}
      </div>
    </button>
  );
}
