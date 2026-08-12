import { type Metadata } from 'next'
import { Container } from '@/components/Container'

export const metadata: Metadata = {
  title: 'Support',
  description: 'Get help with Stattie.',
}

const supportEmail = 'kent.fenwick@gmail.com'

export default function SupportPage() {
  return (
    <Container className="py-16">
      <div className="mx-auto max-w-2xl">
        <h1 className="text-3xl font-medium tracking-tight text-gray-900">
          Stattie Support
        </h1>
        <p className="mt-4 text-gray-700">
          Need help tracking a game, managing your data, or using iCloud sync? Email us and
          include the Stattie version shown in Settings, your iOS version, and a short
          description of what happened.
        </p>

        <a
          href={`mailto:${supportEmail}?subject=Stattie%20Support`}
          className="mt-8 inline-flex rounded-lg bg-orange-600 px-4 py-2 font-semibold text-white hover:bg-orange-700"
        >
          Email {supportEmail}
        </a>

        <div className="mt-12 space-y-8 text-gray-700">
          <section>
            <h2 className="text-xl font-semibold text-gray-900">iCloud sync</h2>
            <p className="mt-3">
              Confirm that you are signed in to iCloud, iCloud Drive is enabled, and Stattie
              is allowed to use iCloud. The app continues to save locally when iCloud is
              unavailable and syncs again when the service is available.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Privacy</h2>
            <p className="mt-3">
              Please do not email player photos, full game exports, passwords, or other
              sensitive information. We will never ask for your Apple ID password.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Policies</h2>
            <p className="mt-3">
              Read the <a href="/privacy" className="text-orange-600 underline">Privacy Policy</a>{' '}
              and <a href="/terms" className="text-orange-600 underline">Terms of Service</a>.
            </p>
          </section>
        </div>
      </div>
    </Container>
  )
}
