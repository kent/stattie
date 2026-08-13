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

export function ShareScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Share Stats</AppScreen.Title>
          <AppScreen.Subtitle>Parent-triggered post-game sharing</AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Share Stats</AppScreen.Title>
          <AppScreen.Subtitle>Parent-triggered post-game sharing</AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <ShareContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <ShareContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function ShareContent() {
  const shareOptions = [
    { label: 'Messages', detail: 'Send to family or friends' },
    { label: 'Mail', detail: 'Email the final summary' },
    { label: 'More…', detail: 'Open the iOS share sheet' },
  ]

  return (
    <div className="px-4 py-6">
      <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
        <p className="text-xs font-semibold tracking-wide text-orange-600 uppercase">
          Final
        </p>
        <h3 className="mt-1 font-semibold text-gray-900">Marcus vs. Tigers</h3>
        <p className="mt-1 text-sm text-gray-500">24 points · 5 rebounds · 7 assists</p>
      </div>

      <div className="mt-6">
        <span className="text-sm font-medium text-gray-900">Share with</span>
        <div className="mt-3 space-y-3">
          {shareOptions.map((option) => (
            <button
              key={option.label}
              type="button"
              className="flex w-full items-center justify-between rounded-xl border border-gray-200 bg-white px-4 py-3 text-left"
            >
              <span className="text-sm font-medium text-gray-900">{option.label}</span>
              <span className="text-xs text-gray-500">{option.detail}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-6 rounded-lg bg-orange-50 p-3 text-xs text-orange-800">
        Nothing is shared until you choose an option after the game.
      </div>
    </div>
  )
}
