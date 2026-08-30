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
    "A single-player stat tracker made for parents. Cover the major sports in Canada, the US, and Europe, track every shift, and choose when to share a post-game summary.",
  applicationName: 'Stattie',
  keywords: [
    'basketball stats',
    'stat tracking',
    'basketball statistics',
    'youth basketball',
    'basketball app',
    'soccer stats',
    'soccer app',
    'hockey stats',
    'baseball stats',
    'football stats',
    'multi sport tracker',
    'parent stat tracker',
    'game tracker',
    'sports stats',
    'basketball scoring',
    'single player stats',
    'parent sports app',
    'basketball analytics',
    'live stats',
    'shift tracking',
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
      "Single-player stat tracking for parents across the major sports, with live shift tracking and parent-triggered post-game sharing.",
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
      "Single-player stat tracking for parents across the major sports, with post-game summaries you choose to share.",
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
