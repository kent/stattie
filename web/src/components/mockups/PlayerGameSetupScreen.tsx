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

export function PlayerGameSetupScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>New Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Set up the game, then <span className="text-white">Start Tracking</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>New Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Set up the game, then <span className="text-white">Start Tracking</span>
          </AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <PlayerGameSetupContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <PlayerGameSetupContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function PlayerGameSetupContent() {
  return (
    <div className="space-y-4 px-4 py-5">
      <div className="rounded-xl bg-gray-50 p-3">
        <div className="text-xs font-semibold uppercase tracking-wide text-gray-500">
          Your player
        </div>
        <div className="mt-2 flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 text-sm font-bold text-orange-700">
            #23
          </div>
          <div>
            <div className="font-semibold text-gray-900">Marcus Johnson</div>
            <div className="text-xs text-gray-500">Ready to track</div>
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-gray-200 bg-white px-3 py-1">
        <InfoRow label="Sport" value="Basketball" />
        <InfoRow label="Opponent" value="Tigers" />
        <InfoRow label="Jersey" value="#23" />
        <InfoRow label="Position" value="Point Guard" />
      </div>

      <div className="rounded-xl border border-orange-200 bg-orange-50 px-3 py-2">
        <div className="text-xs font-medium text-orange-800">
          One player. One game. Every stat in one place.
        </div>
      </div>

      <button className="w-full rounded-lg bg-orange-600 px-3 py-2 text-sm font-semibold text-white">
        Start Tracking
      </button>
    </div>
  )
}
