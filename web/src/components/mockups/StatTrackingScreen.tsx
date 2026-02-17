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

function StatButton({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <button className={`flex flex-col items-center justify-center rounded-xl p-3 ${color}`}>
      <span className="text-2xl font-bold text-white">{value}</span>
      <span className="text-xs text-white/80">{label}</span>
    </button>
  )
}

function ImpactButton({
  label,
  color,
}: {
  label: string
  color: string
}) {
  return (
    <button className={`rounded-xl px-3 py-2 text-left ${color}`}>
      <div className="text-xs font-semibold text-white">{label}</div>
      <div className="mt-1 text-[11px] text-white/80">0</div>
    </button>
  )
}

export function StatTrackingScreen(props: ScreenProps) {
  return (
    <AppScreen className="w-full">
      {props.animated ? (
        <MotionAppScreenHeader {...props.headerAnimation}>
          <AppScreen.Title>Track Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Comets • Basketball <span className="text-white">Shift 2 • 00:16</span>
          </AppScreen.Subtitle>
        </MotionAppScreenHeader>
      ) : (
        <AppScreen.Header>
          <AppScreen.Title>Track Game</AppScreen.Title>
          <AppScreen.Subtitle>
            Comets • Basketball <span className="text-white">Shift 2 • 00:16</span>
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
    <div className="px-4 py-5">
      {/* Player selector */}
      <div className="mb-3 flex items-center gap-2">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-600">
          <span className="text-white font-bold">#23</span>
        </div>
        <div>
          <div className="font-semibold text-gray-900">Marcus Johnson</div>
          <div className="text-xs text-gray-500">Comets • Point Guard</div>
        </div>
        <div className="ml-auto text-right">
          <div className="text-lg font-bold text-gray-900">12 PTS</div>
          <div className="text-xs text-gray-500">4-7 FG</div>
        </div>
      </div>

      {/* Shift controls */}
      <div className="mb-3 rounded-xl border border-orange-200 bg-orange-50 p-3">
        <div className="flex items-center justify-between gap-2">
          <div>
            <div className="text-[11px] font-semibold uppercase tracking-wide text-orange-700">
              Current shift
            </div>
            <div className="text-sm font-semibold text-gray-900">00:16 elapsed</div>
          </div>
          <button className="rounded-full bg-orange-600 px-3 py-1 text-xs font-semibold text-white">
            End Shift
          </button>
        </div>
        <div className="mt-2 text-[11px] text-gray-600">
          End shift opens a quick summary, then tap Start New Shift.
        </div>
      </div>

      {/* Core shooting buttons */}
      <div className="mb-3 grid grid-cols-3 gap-2">
        <StatButton label="2PT Made" value="+2" color="bg-green-500" />
        <StatButton label="3PT Made" value="+3" color="bg-green-600" />
        <StatButton label="FT Made" value="+1" color="bg-green-400" />
        <StatButton label="2PT Miss" value="0" color="bg-gray-400" />
        <StatButton label="3PT Miss" value="0" color="bg-gray-500" />
        <StatButton label="FT Miss" value="0" color="bg-gray-400" />
      </div>

      {/* Basketball-specific impact buttons */}
      <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-gray-500">
        Basketball impact
      </div>
      <div className="grid grid-cols-2 gap-2">
        <ImpactButton label="Missed Drive" color="bg-orange-500" />
        <ImpactButton label="Bad Play Offense" color="bg-red-500" />
        <ImpactButton label="Bad Play Defense" color="bg-rose-500" />
        <ImpactButton label="Great Play Offense" color="bg-amber-500" />
        <ImpactButton label="Great Play Defense" color="bg-green-500" />
      </div>
    </div>
  )
}
