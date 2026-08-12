import { type Metadata, type Viewport } from 'next'
import { Inter } from 'next/font/google'
import clsx from 'clsx'

import '@/styles/tailwind.css'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#EA580C',
}

export const metadata: Metadata = {
  metadataBase: new URL('https://www.stattie.com'),
  title: {
    template: '%s - Stattie',
    default: 'Stattie - Track Every Game. Own Every Stat.',
  },
  description:
    'Team-first basketball and soccer stat tracking for players, coaches, and families. Select sport and team before games, track shifts live, and manage games with quick edit/delete actions.',
  applicationName: 'Stattie',
  keywords: [
    'basketball stats',
    'stat tracking',
    'basketball statistics',
    'youth basketball',
    'basketball app',
    'soccer stats',
    'soccer app',
    'multi sport tracker',
    'game tracker',
    'sports stats',
    'basketball scoring',
    'player stats',
    'coach app',
    'basketball analytics',
    'live stats',
    'shift tracking',
    'team-based jersey tracking',
    'sport-specific tracking',
    'game edit delete',
    'stat tracker',
    'basketball box score',
  ],
  authors: [{ name: 'Stattie' }],
  creator: 'Stattie',
  publisher: 'Stattie',
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: 'https://www.stattie.com',
    siteName: 'Stattie',
    title: 'Stattie - Track Every Game. Own Every Stat.',
    description:
      'Team-first basketball and soccer tracking with shift flow, sport-aware setup, and fast game management.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Stattie - Sports Stats Tracking App',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Stattie - Track Every Game. Own Every Stat.',
    description:
      'Team-first basketball and soccer tracking with shift flow and fast game management.',
    images: ['/og-image.png'],
  },
  appleWebApp: {
    capable: true,
    title: 'Stattie',
    statusBarStyle: 'black-translucent',
  },
  itunes: {
    appId: '6758022135',
  },
  category: 'sports',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/icon-192.png', type: 'image/png', sizes: '192x192' },
      { url: '/icon-512.png', type: 'image/png', sizes: '512x512' },
    ],
    apple: [
      { url: '/apple-touch-icon.png', sizes: '180x180', type: 'image/png' },
    ],
  },
  manifest: '/manifest.json',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={clsx('bg-gray-50 antialiased', inter.variable)}>
      <body>{children}</body>
    </html>
  )
}
