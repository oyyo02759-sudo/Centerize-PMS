import type { PropertyGridMatrix, PropertySummary } from '@/types/pms';

const BASE = process.env.NEXT_PUBLIC_API_BASE ?? 'http://localhost:3000';

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`GET ${path} → ${res.status}`);
  return res.json() as Promise<T>;
}

export const api = {
  listProperties: () => get<PropertySummary[]>('/properties'),
  getGridMatrix: (propertyId: string) =>
    get<PropertyGridMatrix>(`/properties/${propertyId}/grid`),
};
