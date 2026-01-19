import { Container } from '@/components/Container'
import { Logomark } from '@/components/Logo'
import { AppStoreLink } from '@/components/AppStoreLink'

function CheckIcon(props: React.ComponentPropsWithoutRef<'svg'>) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        d="M9.307 12.248a.75.75 0 1 0-1.114 1.004l1.114-1.004ZM11 15.25l-.557.502a.75.75 0 0 0 1.15-.043L11 15.25Zm4.844-5.041a.75.75 0 0 0-1.188-.918l1.188.918Zm-7.651 3.043 2.25 2.5 1.114-1.004-2.25-2.5-1.114 1.004Zm3.4 2.457 4.25-5.5-1.187-.918-4.25 5.5 1.188.918Z"
        fill="currentColor"
      />
      <circle
        cx="12"
        cy="12"
        r="8.25"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

const features = [
  'Unlimited players and games',
  'Real-time stat tracking',
  'iCloud sharing with team',
  'Detailed game summaries',
  'Offline mode',
  'All future updates included',
]

export function Pricing() {
  return (
    <section
      id="pricing"
      aria-labelledby="pricing-title"
      className="border-t border-gray-200 bg-gray-100 py-20 sm:py-32"
    >
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <h2
            id="pricing-title"
            className="text-3xl font-medium tracking-tight text-gray-900"
          >
            Simple pricing. No surprises.
          </h2>
          <p className="mt-2 text-lg text-gray-600">
            One price. Yours forever. No subscriptions, no ads, no in-app purchases.
          </p>
        </div>

        <div className="mx-auto mt-16 max-w-lg">
          <div className="flex flex-col overflow-hidden rounded-3xl bg-white p-8 shadow-lg shadow-gray-900/5">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <Logomark className="h-10 w-10 flex-none fill-orange-600 stroke-orange-600" />
                <span className="ml-4 text-lg font-semibold text-gray-900">Stattie</span>
              </div>
              <div className="text-right">
                <div className="text-4xl font-bold tracking-tight text-gray-900">$4.99</div>
                <div className="text-sm text-gray-500">one-time purchase</div>
              </div>
            </div>

            <p className="mt-6 text-gray-700">
              Everything you need to track basketball stats for your players,
              with all future updates included.
            </p>

            <ul role="list" className="mt-8 space-y-3">
              {features.map((feature) => (
                <li key={feature} className="flex items-center">
                  <CheckIcon className="h-6 w-6 flex-none text-orange-600" />
                  <span className="ml-3 text-gray-700">{feature}</span>
                </li>
              ))}
            </ul>

            <div className="mt-8 flex justify-center">
              <AppStoreLink />
            </div>

            <p className="mt-6 text-center text-sm text-gray-500">
              No account required. No subscription. Just download and start tracking.
            </p>
          </div>
        </div>
      </Container>
    </section>
  )
}
