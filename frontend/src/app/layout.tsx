import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Centerize PMS',
  description: 'Multi-Property Management System',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="th">
      <body className="bg-gray-50 text-gray-900 antialiased">
        <nav className="h-12 bg-white border-b border-gray-200 flex items-center px-6 shadow-sm">
          <span className="font-semibold text-sm tracking-wide text-indigo-700">
            Centerize PMS
          </span>
        </nav>
        <main className="max-w-7xl mx-auto px-4 py-6">{children}</main>
      </body>
    </html>
  );
}
