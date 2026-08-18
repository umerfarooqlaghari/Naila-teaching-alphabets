import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Vaila Admin - Pronunciation Analytics & Dashboard',
  description: 'Admin portal for monitoring speech therapy and pronunciation practice for partially deaf children.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
