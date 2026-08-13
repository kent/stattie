import { Container } from '@/components/Container'

const faqs = [
  [
    {
      question: 'What sports can I track?',
      answer:
        'Stattie supports basketball and soccer. Pick the sport for each game and the stat buttons adapt automatically.',
    },
    {
      question: 'Does each game focus on one player?',
      answer:
        'Yes. Stattie is designed for a parent to focus on one player at a time and keep that player\'s game history clear.',
    },
    {
      question: 'What stats can I track?',
      answer:
        'Basketball includes shooting, rebounds, assists, steals, and impact actions. Soccer includes goals, shots, assists, saves, passes, tackles, interceptions, corners, fouls, and cards.',
    },
  ],
  [
    {
      question: 'Is there a subscription?',
      answer:
        'No. Stattie is free, with no subscriptions, ads, or in-app purchases.',
    },
    {
      question: 'Can I edit or delete games later?',
      answer:
        'Yes. You can quickly edit or delete games from your game list.',
    },
    {
      question: 'Can I share a game with friends or family?',
      answer:
        'Yes. After the game, you can choose to send a text summary using the standard iOS share sheet. Stattie never shares it automatically.',
    },
  ],
  [
    {
      question: 'What devices does it work on?',
      answer:
        'Stattie works on iPhone and iPad. Your data can sync between your own devices via iCloud.',
    },
    {
      question: 'How do shifts work during tracking?',
      answer:
        'Tap End Shift for a quick recap, then start a new shift immediately to keep recording the same player without breaking the flow.',
    },
    {
      question: 'Does it work without internet?',
      answer:
        "Yes. Stattie works offline. Your stats are saved locally and can sync to iCloud when you're back online.",
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
              href="/support"
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
