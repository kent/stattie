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

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-gray-100 py-2 last:border-b-0">
      <span className="text-xs text-gray-500">{label}</span>
      <span className="text-sm font-medium text-gray-900">{value}</span>
    </div>
  )
}

export function TeamGameSetupScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>New Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Pick team + sport before <span className="text-white">Start Game</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>New Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Pick team + sport before <span className="text-white">Start Game</span>
          </AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <TeamGameSetupContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <TeamGameSetupContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function TeamGameSetupContent() {
  return (
    <div className="space-y-4 px-4 py-5">
      <div className="rounded-xl bg-gray-50 p-3">
        <div className="text-xs font-semibold uppercase tracking-wide text-gray-500">
          Player
        </div>
        <div className="mt-2 flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 text-sm font-bold text-orange-700">
            #0
          </div>
          <div>
            <div className="font-semibold text-gray-900">Emma Fenwick</div>
            <div className="text-xs text-gray-500">Adding to game</div>
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-gray-200 bg-white px-3 py-1">
        <InfoRow label="Team (required)" value="Comets" />
        <InfoRow label="Sport (required)" value="Basketball or Soccer" />
        <InfoRow label="Jersey in Team" value="#0" />
        <InfoRow label="Position in Team" value="Point Guard" />
      </div>

      <div className="rounded-xl border border-orange-200 bg-orange-50 px-3 py-2">
        <div className="text-xs font-medium text-orange-800">
          Start Game is disabled until a team is selected.
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <button className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700">
          Change Team
        </button>
        <button className="rounded-lg bg-orange-600 px-3 py-2 text-sm font-semibold text-white">
          Start Game
        </button>
      </div>
    </div>
  )
}
