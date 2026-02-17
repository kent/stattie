'use client'

import { type MotionProps, motion } from 'framer-motion'
import { AppScreen } from '@/components/AppScreen'

const MotionAppScreenHeader = motion(AppScreen.Header)
const MotionAppScreenBody = motion(AppScreen.Body)

interface CustomAnimationProps {
  isForwards: boolean
  changeCount: number
}

type ScreenProps =
  | {
      animated: true
      custom: CustomAnimationProps
      headerAnimation: MotionProps
      bodyAnimation: MotionProps
    }
  | { animated?: false }

const games = [
  { id: 'g1', label: 'Game vs Tigers', team: 'Comets', sport: 'Basketball', date: 'Feb 17, 2026 • 1:16 AM', points: 12 },
  { id: 'g2', label: 'Game vs Hawks', team: 'Comets', sport: 'Basketball', date: 'Feb 12, 2026 • Final', points: 18 },
]

function GameRow({
  game,
  showActions = false,
}: {
  game: (typeof games)[number]
  showActions?: boolean
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-3">
      <div className="flex items-start justify-between gap-2">
        <div>
          <div className="text-sm font-semibold text-gray-900">{game.label}</div>
          <div className="mt-0.5 text-xs text-gray-500">{game.date}</div>
          <div className="mt-1 flex gap-1">
            <span className="rounded-full bg-orange-100 px-2 py-0.5 text-[10px] font-semibold text-orange-700">
              {game.team}
            </span>
            <span className="rounded-full bg-blue-100 px-2 py-0.5 text-[10px] font-semibold text-blue-700">
              {game.sport}
            </span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-lg font-bold text-orange-600">{game.points}</div>
          <div className="text-[10px] text-gray-500">PTS</div>
        </div>
      </div>
      {showActions && (
        <div className="mt-2 flex gap-2 border-t border-gray-100 pt-2">
          <button className="rounded-full bg-gray-100 px-2.5 py-1 text-[11px] font-medium text-gray-700">
            Swipe to Edit
          </button>
          <button className="rounded-full bg-red-100 px-2.5 py-1 text-[11px] font-medium text-red-700">
            Swipe to Delete
          </button>
        </div>
      )}
    </div>
  )
}

export function GameManagementScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Games</AppScreen.Title>
          <AppScreen.Subtitle>
            Manage active games for <span className="text-white">Comets</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Games</AppScreen.Title>
          <AppScreen.Subtitle>
            Manage active games for <span className="text-white">Comets</span>
          </AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <GameManagementContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <GameManagementContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function GameManagementContent() {
  return (
    <div className="space-y-3 px-4 py-5">
      <div>
        <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500">
          Active Games
        </div>
        <GameRow game={games[0]} showActions />
      </div>

      <div>
        <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-gray-500">
          Recent Games
        </div>
        <div className="space-y-2">
          <GameRow game={games[1]} />
        </div>
      </div>
    </div>
  )
}
