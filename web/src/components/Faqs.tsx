import { Container } from '@/components/Container'

const faqs = [
  [
    {
      question: 'Can multiple people track the same game?',
      answer:
        'Yes! With iCloud sharing, you can invite coaches, parents, or anyone else to view and track stats for your team. Everyone sees updates in real-time.',
    },
    {
      question: 'Does it work without internet?',
      answer:
        'Absolutely. Stattie works completely offline. Your stats are saved locally and sync to iCloud automatically when you\'re back online.',
    },
    {
      question: 'What stats can I track?',
      answer:
        'Points (2PT, 3PT, FT), rebounds, assists, steals, blocks, turnovers, and fouls. Everything you need for a complete game summary.',
    },
  ],
  [
    {
      question: 'Is there a subscription?',
      answer:
        'Nope! Stattie is a one-time purchase of $4.99. No subscriptions, no ads, no in-app purchases. You own it forever.',
    },
    {
      question: 'How many players can I add?',
      answer:
        'Unlimited! Add as many players and games as you want. There are no artificial limits.',
    },
    {
      question: 'Can I export my data?',
      answer:
        'Yes, you can share game summaries as images or export detailed stats. Your data is always accessible.',
    },
  ],
  [
    {
      question: 'What devices does it work on?',
      answer:
        'Stattie works on iPhone and iPad. Your data syncs seamlessly between devices via iCloud.',
    },
    {
      question: 'Is my data private?',
      answer:
        'Your data is stored securely in your personal iCloud account. We never see or access your information.',
    },
    {
      question: 'Do you offer refunds?',
      answer:
        'App Store purchases are handled by Apple. If you\'re not satisfied, you can request a refund through Apple within their refund window.',
    },
  ],
]

export function Faqs() {
  return (
    <section
      id="faqs"
      aria-labelledby="faqs-title"
      className="border-t border-gray-200 py-20 sm:py-32"
    >
      <Container>
        <div className="mx-auto max-w-2xl lg:mx-0">
          <h2
            id="faqs-title"
            className="text-3xl font-medium tracking-tight text-gray-900"
          >
            Frequently asked questions
          </h2>
          <p className="mt-2 text-lg text-gray-600">
            If you have anything else you want to ask,{' '}
            <a
              href="mailto:support@stattie.app"
              className="text-orange-600 underline"
            >
              reach out to us
            </a>
            .
          </p>
        </div>
        <ul
          role="list"
          className="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 sm:mt-20 lg:max-w-none lg:grid-cols-3"
        >
          {faqs.map((column, columnIndex) => (
            <li key={columnIndex}>
              <ul role="list" className="space-y-10">
                {column.map((faq, faqIndex) => (
                  <li key={faqIndex}>
                    <h3 className="text-lg/6 font-semibold text-gray-900">
                      {faq.question}
                    </h3>
                    <p className="mt-4 text-sm text-gray-700">{faq.answer}</p>
                  </li>
                ))}
              </ul>
            </li>
          ))}
        </ul>
      </Container>
    </section>
  )
}
