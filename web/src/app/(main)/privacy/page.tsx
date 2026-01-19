import { type Metadata } from 'next'
import { Container } from '@/components/Container'

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Stattie Privacy Policy - Learn how we protect your data.',
}

export default function PrivacyPage() {
  return (
    <Container className="py-16">
      <div className="mx-auto max-w-2xl">
        <h1 className="text-3xl font-medium tracking-tight text-gray-900">
          Privacy Policy
        </h1>
        <p className="mt-4 text-sm text-gray-500">Last updated: January 2025</p>

        <div className="mt-8 space-y-8 text-gray-700">
          <section>
            <h2 className="text-xl font-semibold text-gray-900">Overview</h2>
            <p className="mt-4">
              Stattie is designed with your privacy in mind. We believe your data belongs to you,
              and we&apos;ve built our app to respect that principle.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Data Storage</h2>
            <p className="mt-4">
              All your data is stored locally on your device and in your personal iCloud account.
              We do not have access to your data, and we do not store any information on our servers.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">iCloud Sync</h2>
            <p className="mt-4">
              When you enable iCloud sync, your data is stored in your personal iCloud account
              using Apple&apos;s CloudKit framework. This data is protected by Apple&apos;s security
              measures and your Apple ID credentials.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Data Sharing</h2>
            <p className="mt-4">
              When you share data with other users through iCloud sharing, only the people you
              explicitly invite can access that shared data. You control who has access and can
              revoke access at any time.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Analytics</h2>
            <p className="mt-4">
              We do not collect any personal information or usage analytics. We don&apos;t track
              how you use the app, what stats you record, or any other information about your activity.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Third Parties</h2>
            <p className="mt-4">
              We do not share, sell, or transfer your data to any third parties. The only external
              service involved is Apple&apos;s iCloud, which is necessary for sync and sharing features.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-gray-900">Contact</h2>
            <p className="mt-4">
              If you have any questions about this privacy policy, please contact us at{' '}
              <a href="mailto:privacy@stattie.app" className="text-orange-600 underline">
                privacy@stattie.app
              </a>
              .
            </p>
          </section>
        </div>
      </div>
    </Container>
  )
}
