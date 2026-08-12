import { Container } from '@/components/Container'

const coachingHighlights = [
  'Generate an end-of-game coaching report locally from game stats and historical performance.',
  'Surface the top 3 focus points for the next game with clear, specific practice intent.',
  'Keep recommendations player-specific so each athlete gets actionable next steps.',
]

const academyHighlights = [
  'Build a ranked 1-2-3 improvement plan per player based on role, position, and trends.',
  'Refresh priorities continuously as new shifts and games are tracked.',
  'Attach free learning resources, including YouTube drills, to each recommended focus area.',
]

function NumberBadge({ value }: { value: number }) {
  return (
    <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-orange-600 text-sm font-semibold text-white">
      {value}
    </span>
  )
}

export function AICoachingAcademy() {
  return (
    <section
      id="ai-coaching"
      aria-label="On-device coaching and academy planning"
      className="border-t border-gray-200 py-20 sm:py-32"
    >
      <Container>
        <div className="mx-auto max-w-3xl text-center">
          <h2 className="text-3xl font-medium tracking-tight text-gray-900 sm:text-4xl">
            Turn stats into coaching decisions.
          </h2>
          <p className="mt-4 text-lg text-gray-600">
            Stattie turns raw tracking data into practical guidance right on
            your device, so players can act on it right away.
          </p>
        </div>
        <div className="mt-16 grid grid-cols-1 gap-8 lg:grid-cols-2">
          <article className="rounded-3xl border border-gray-200 bg-white p-8 shadow-sm">
            <p className="text-sm font-semibold tracking-wide text-orange-600 uppercase">
              On-Device Coaching
            </p>
            <h3 className="mt-3 text-2xl font-semibold text-gray-900">
              Post-game next-step insights
            </h3>
            <p className="mt-3 text-gray-700">
              After every game, generate a focused coaching summary designed to
              help players prepare better for the next matchup.
            </p>
            <ol className="mt-8 space-y-4">
              {coachingHighlights.map((item, index) => (
                <li key={item} className="flex items-start gap-3">
                  <NumberBadge value={index + 1} />
                  <p className="pt-0.5 text-sm text-gray-700">{item}</p>
                </li>
              ))}
            </ol>
            <p className="mt-8 rounded-2xl bg-orange-50 p-4 text-sm text-orange-900">
              Coaching is generated entirely on-device. Player, game, and
              team data never leaves the app for coaching.
            </p>
          </article>
          <article
            id="academy"
            className="rounded-3xl border border-gray-200 bg-gray-900 p-8 text-white shadow-sm"
          >
            <p className="text-sm font-semibold tracking-wide text-orange-400 uppercase">
              Academy
            </p>
            <h3 className="mt-3 text-2xl font-semibold">
              A living development plan
            </h3>
            <p className="mt-3 text-gray-300">
              Every player gets an always-current training queue tied directly
              to how they are performing in real games.
            </p>
            <ol className="mt-8 space-y-4">
              {academyHighlights.map((item, index) => (
                <li key={item} className="flex items-start gap-3">
                  <NumberBadge value={index + 1} />
                  <p className="pt-0.5 text-sm text-gray-300">{item}</p>
                </li>
              ))}
            </ol>
          </article>
        </div>
      </Container>
    </section>
  )
}
