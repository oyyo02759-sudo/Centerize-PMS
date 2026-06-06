'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import type { PropertyGridMatrix } from '@/types/pms';

interface State {
  data: PropertyGridMatrix | null;
  loading: boolean;
  error: string | null;
}

export function usePropertyGrid(propertyId: string) {
  const [state, setState] = useState<State>({ data: null, loading: true, error: null });

  useEffect(() => {
    let cancelled = false;

    api
      .getGridMatrix(propertyId)
      .then((data) => { if (!cancelled) setState({ data, loading: false, error: null }); })
      .catch((err: unknown) => {
        if (!cancelled)
          setState({ data: null, loading: false, error: String(err) });
      });

    return () => { cancelled = true; };
  }, [propertyId]);

  const updateRoom = (roomId: string, patch: Partial<PropertyGridMatrix['rooms'][number]>) => {
    setState((prev) => {
      if (!prev.data) return prev;
      return {
        ...prev,
        data: {
          ...prev.data,
          rooms: prev.data.rooms.map((r) => (r.id === roomId ? { ...r, ...patch } : r)),
        },
      };
    });
  };

  return { ...state, updateRoom };
}
