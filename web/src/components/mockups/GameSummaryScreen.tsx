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

const players = [
  { name: 'M. Johnson', number: 23, pts: 24, reb: 5, ast: 7, fg: '9-15' },
  { name: 'D. Williams', number: 11, pts: 18, reb: 8, ast: 2, fg: '7-12' },
  { name: 'K. Thompson', number: 5, pts: 14, reb: 3, ast: 4, fg: '5-11' },
  { name: 'J. Davis', number: 32, pts: 12, reb: 11, ast: 1, fg: '5-8' },
  { name: 'R. Brown', number: 7, pts: 8, reb: 2, ast: 6, fg: '3-7' },
]

export function GameSummaryScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Game Summary</AppScreen.Title>
          <AppScreen.Subtitle>
            <span className="text-green-400">W</span> 76-68 vs. Eagles
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Game Summary</AppScreen.Title>
          <AppScreen.Subtitle>
            <span className="text-green-400">W</span> 76-68 vs. Eagles
          </AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <GameSummaryContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <GameSummaryContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function GameSummaryContent() {
  return (
    <div className="px-4 py-4">
      {/* Team totals */}
      <div className="mb-4 rounded-lg bg-orange-50 p-3">
        <div className="flex justify-between text-sm">
          <span className="font-semibold text-orange-900">Team Totals</span>
          <span className="text-orange-700">76 PTS • 29 REB • 20 AST</span>
        </div>
        <div className="mt-1 text-xs text-orange-600">
          FG: 29-53 (54.7%) • 3PT: 8-18 (44.4%) • FT: 10-14 (71.4%)
        </div>
      </div>

      {/* Stats table header */}
      <div className="grid grid-cols-6 gap-1 border-b border-gray-200 pb-2 text-xs font-semibold text-gray-500">
        <div className="col-span-2">Player</div>
        <div className="text-center">PTS</div>
        <div className="text-center">REB</div>
        <div className="text-center">AST</div>
        <div className="text-center">FG</div>
      </div>

      {/* Player rows */}
      <div className="divide-y divide-gray-100">
        {players.map((player) => (
          <div key={player.number} className="grid grid-cols-6 gap-1 py-2 text-sm">
            <div className="col-span-2 flex items-center gap-1">
              <span className="text-xs text-gray-400">#{player.number}</span>
              <span className="font-medium text-gray-900">{player.name}</span>
            </div>
            <div className="text-center font-semibold text-gray-900">{player.pts}</div>
            <div className="text-center text-gray-600">{player.reb}</div>
            <div className="text-center text-gray-600">{player.ast}</div>
            <div className="text-center text-xs text-gray-500">{player.fg}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
