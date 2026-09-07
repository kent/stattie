import { Footer } from '@/components/Footer'
import { Header } from '@/components/Header'

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:z-[60] focus:rounded-lg focus:bg-white focus:p-4">Skip to content</a>
      <Header />
      <main id="main-content" tabIndex={-1} className="flex-auto">{children}</main>
      <Footer />
    </>
  )
}
