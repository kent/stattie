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

const sharedWith = [
  { name: 'Coach Martinez', role: 'Head Coach', avatar: 'CM' },
  { name: 'Sarah Johnson', role: 'Parent', avatar: 'SJ' },
  { name: 'Mike Williams', role: 'Asst. Coach', avatar: 'MW' },
]

export function ShareScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Share Stats</AppScreen.Title>
          <AppScreen.Subtitle>
            Invite your team via <span className="text-white">iCloud</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Share Stats</AppScreen.Title>
          <AppScreen.Subtitle>
            Invite your team via <span className="text-white">iCloud</span>
          </AppScreen.Subtitle>
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
  return (
    <div className="px-4 py-6">
      {/* Invite section */}
      <div className="mb-6">
        <label className="text-sm font-medium text-gray-900">Invite via email</label>
        <div className="mt-2 flex gap-2">
          <input
            type="email"
            placeholder="coach@team.com"
            className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm"
          />
          <button className="rounded-lg bg-orange-600 px-4 py-2 text-sm font-semibold text-white">
            Invite
          </button>
        </div>
      </div>

      {/* Shared with section */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <span className="text-sm font-medium text-gray-900">Shared with</span>
          <span className="text-xs text-gray-500">3 people</span>
        </div>
        <div className="space-y-3">
          {sharedWith.map((person) => (
            <div key={person.name} className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100">
                <span className="text-sm font-semibold text-orange-700">{person.avatar}</span>
              </div>
              <div className="flex-1">
                <div className="font-medium text-gray-900">{person.name}</div>
                <div className="text-xs text-gray-500">{person.role}</div>
              </div>
              <div className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
                Active
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* iCloud info */}
      <div className="mt-6 rounded-lg bg-blue-50 p-3">
        <div className="flex items-start gap-2">
          <svg className="h-5 w-5 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          <div className="text-xs text-blue-700">
            Stats sync automatically via iCloud. Everyone sees updates in real-time.
          </div>
        </div>
      </div>
    </div>
  )
}
