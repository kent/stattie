import { type Metadata } from 'next'
import { Container } from '@/components/Container'

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'How Stattie handles app data and protects your privacy.',
}

export default function PrivacyPage() {
  return (
    <Container className="py-16">
      <div className="mx-auto max-w-2xl">
        <h1 className="text-3xl font-medium tracking-tight text-gray-900">
          Privacy Policy
        </h1>
        <p className="mt-4 text-sm text-gray-500">Last updated: August 12, 2026</p>

        <div className="mt-8 space-y-8 text-gray-700">
          <section>
            <h2 className="text-xl font-semibold text-gray-900">Overview</h2>
            <p className="mt-4">
              Stattie does not use advertising, third-party analytics, or cross-app tracking.
              The app is designed to keep the player and game information you enter under
              your control.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Information you create</h2>
            <p className="mt-4">
              You may enter a player name, photo, game details, statistics, notes, and app
              preferences. This content is stored on your device. If you use iCloud, Apple
              also stores it in your private iCloud account so it can sync between your
              devices.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">How information is used</h2>
            <p className="mt-4">
              Stattie uses your information to provide game tracking, shift and game
              summaries, trends, and notifications you enable.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">iCloud</h2>
            <p className="mt-4">
              iCloud sync is optional and is provided by Apple&apos;s CloudKit service. Stattie
              does not operate a separate account system or developer database for your app
              content. Apple processes iCloud data according to your Apple account settings
              and Apple&apos;s privacy terms.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Sharing</h2>
            <p className="mt-4">
              After a game, you can choose to share its summary. Only when you select an iOS
              share action is that content sent to the friend or family member you choose
              using Apple&apos;s share sheet. Stattie does not receive a copy or share game data
              automatically. Be careful when sharing information about minors.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Tracking and analytics</h2>
            <p className="mt-4">
              Stattie does not include advertising SDKs, use the advertising identifier,
              profile you across apps or websites, or collect usage analytics. Apple may
              process App Store, iCloud, and device diagnostic information under Apple&apos;s own
              policies and the diagnostic choices on your device.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Retention and deletion</h2>
            <p className="mt-4">
              Your content remains on your device and, when enabled, in iCloud until you
              delete it. Deleting content in Stattie removes it from the app and allows that
              deletion to sync through iCloud. You can also manage Stattie&apos;s iCloud data in
              your Apple account settings.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Children&apos;s information</h2>
            <p className="mt-4">
              Stattie is intended for parents and other adults. If you add information about
              a child or another person, you are responsible for having permission to record
              it and to share any post-game summary.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Contact</h2>
            <p className="mt-4">
              Questions or privacy requests can be sent to{' '}
              <a href="mailto:kent.fenwick@gmail.com" className="text-orange-600 underline">
                kent.fenwick@gmail.com
              </a>
              . Please do not include player records or other sensitive app content in email.
            </p>
          </section>
        </div>
      </div>
    </Container>
  )
}
