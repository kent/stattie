'use client'

import { forwardRef } from 'react'
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

function StatButton({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <button className={`flex flex-col items-center justify-center rounded-xl p-3 ${color}`}>
      <span className="text-2xl font-bold text-white">{value}</span>
      <span className="text-xs text-white/80">{label}</span>
    </button>
  )
}

export function StatTrackingScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Live Game</AppScreen.Title>
          <AppScreen.Subtitle>
            vs. Eagles <span className="text-white">Q2 • 4:32</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Live Game</AppScreen.Title>
          <AppScreen.Subtitle>
            vs. Eagles <span className="text-white">Q2 • 4:32</span>
          </AppScreen.Subtitle>
        </AppScreen.Header>
      )}
      {props.animated ? (
        <MotionAppScreenBody {...props.bodyAnimation} custom={props.custom}>
          <StatTrackingContent />
        </MotionAppScreenBody>
      ) : (
        <AppScreen.Body>
          <StatTrackingContent />
        </AppScreen.Body>
      )}
    </AppScreen>
  )
}

function StatTrackingContent() {
  return (
    <div className="px-4 py-6">
      {/* Player selector */}
      <div className="mb-4 flex items-center gap-2">
        <div className="h-10 w-10 rounded-full bg-orange-600 flex items-center justify-center">
          <span className="text-white font-bold">#23</span>
        </div>
        <div>
          <div className="font-semibold text-gray-900">Marcus Johnson</div>
          <div className="text-xs text-gray-500">Point Guard</div>
        </div>
        <div className="ml-auto text-right">
          <div className="text-lg font-bold text-gray-900">12 PTS</div>
          <div className="text-xs text-gray-500">4-7 FG</div>
        </div>
      </div>

      {/* Quick stat buttons */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        <StatButton label="2PT Made" value="+2" color="bg-green-500" />
        <StatButton label="3PT Made" value="+3" color="bg-green-600" />
        <StatButton label="FT Made" value="+1" color="bg-green-400" />
        <StatButton label="2PT Miss" value="0" color="bg-red-400" />
        <StatButton label="3PT Miss" value="0" color="bg-red-500" />
        <StatButton label="FT Miss" value="0" color="bg-red-400" />
      </div>

      {/* Other stats */}
      <div className="grid grid-cols-4 gap-2">
        <button className="flex flex-col items-center rounded-lg bg-gray-100 p-2">
          <span className="text-sm font-semibold text-gray-900">REB</span>
          <span className="text-xs text-gray-500">Rebound</span>
        </button>
        <button className="flex flex-col items-center rounded-lg bg-gray-100 p-2">
          <span className="text-sm font-semibold text-gray-900">AST</span>
          <span className="text-xs text-gray-500">Assist</span>
        </button>
        <button className="flex flex-col items-center rounded-lg bg-gray-100 p-2">
          <span className="text-sm font-semibold text-gray-900">STL</span>
          <span className="text-xs text-gray-500">Steal</span>
        </button>
        <button className="flex flex-col items-center rounded-lg bg-gray-100 p-2">
          <span className="text-sm font-semibold text-gray-900">BLK</span>
          <span className="text-xs text-gray-500">Block</span>
        </button>
      </div>
    </div>
  )
}
