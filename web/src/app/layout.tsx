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
  metadataBase: new URL('https://stattie.app'),
  title: {
    template: '%s - Stattie',
    default: 'Stattie - Track Every Shot. Own Every Stat.',
  },
  description:
    'Real-time basketball statistics tracking for players, coaches, and families. Record games live, share with your team via iCloud, and keep a complete history of every performance.',
  applicationName: 'Stattie',
  keywords: [
    'basketball stats',
    'stat tracking',
    'basketball statistics',
    'youth basketball',
    'basketball app',
    'game tracker',
    'sports stats',
    'basketball scoring',
    'player stats',
    'coach app',
    'basketball analytics',
    'live stats',
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
    url: 'https://stattie.app',
    siteName: 'Stattie',
    title: 'Stattie - Track Every Shot. Own Every Stat.',
    description:
      'Real-time basketball statistics tracking for players, coaches, and families. Record games live, share with your team via iCloud.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Stattie - Basketball Stats Tracking App',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Stattie - Track Every Shot. Own Every Stat.',
    description:
      'Real-time basketball statistics tracking for players, coaches, and families.',
    images: ['/og-image.png'],
  },
  appleWebApp: {
    capable: true,
    title: 'Stattie',
    statusBarStyle: 'black-translucent',
  },
  appLinks: {
    ios: {
      app_store_id: 'YOUR_APP_STORE_ID',
      app_name: 'Stattie',
      url: 'stattie://',
    },
  },
  itunes: {
    appId: 'YOUR_APP_STORE_ID',
    appArgument: 'stattie://',
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
      { url: '/icon.svg', type: 'image/svg+xml' },
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
      <head>
        <link rel="canonical" href="https://stattie.app" />
        <meta name="apple-itunes-app" content="app-id=YOUR_APP_STORE_ID" />
        <meta name="google-site-verification" content="YOUR_GOOGLE_VERIFICATION_CODE" />
      </head>
      <body>{children}</body>
    </html>
  )
}
