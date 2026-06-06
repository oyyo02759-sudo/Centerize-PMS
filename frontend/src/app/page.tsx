import Link from 'next/link';
import { api } from '@/lib/api';

export default async function HomePage() {
  const properties = await api.listProperties().catch(() => []);

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">รายการอาคาร</h1>
      {properties.length === 0 && (
        <p className="text-gray-400 text-sm">ไม่พบข้อมูลอาคาร</p>
      )}
      <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {properties.map((p) => (
          <li key={p.id}>
            <Link
              href={`/properties/${p.id}/grid`}
              className="block rounded-xl border border-gray-200 bg-white p-5 shadow-sm hover:shadow-md transition-shadow"
            >
              <p className="font-bold text-gray-900">{p.name}</p>
              <p className="text-xs text-gray-400 mt-0.5">{p.code}</p>
              <p className="text-xs text-indigo-600 mt-3">
                Grid {p.gridRows}×{p.gridColumns} · {p.gridRows * p.gridColumns} ห้อง
              </p>
              {p.locationNotes && (
                <p className="text-xs text-gray-500 mt-1 truncate">{p.locationNotes}</p>
              )}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
