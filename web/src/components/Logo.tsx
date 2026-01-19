export function Logomark(props: React.ComponentPropsWithoutRef<'svg'>) {
  return (
    <svg viewBox="0 0 40 40" aria-hidden="true" {...props}>
      {/* Basketball icon */}
      <circle cx="20" cy="20" r="18" strokeWidth="2" stroke="currentColor" fill="none" />
      <path
        d="M20 2 C20 2 20 38 20 38"
        stroke="currentColor"
        strokeWidth="2"
        fill="none"
      />
      <path
        d="M2 20 C2 20 38 20 38 20"
        stroke="currentColor"
        strokeWidth="2"
        fill="none"
      />
      <path
        d="M6 8 C12 14 12 26 6 32"
        stroke="currentColor"
        strokeWidth="2"
        fill="none"
      />
      <path
        d="M34 8 C28 14 28 26 34 32"
        stroke="currentColor"
        strokeWidth="2"
        fill="none"
      />
    </svg>
  )
}

export function Logo(props: React.ComponentPropsWithoutRef<'svg'>) {
  return (
    <svg viewBox="0 0 140 40" aria-hidden="true" {...props}>
      <Logomark width="40" height="40" className="fill-orange-600 stroke-orange-600" />
      <text
        x="48"
        y="28"
        className="fill-gray-900"
        style={{ fontFamily: 'var(--font-inter)', fontSize: '24px', fontWeight: 600 }}
      >
        Stattie
      </text>
    </svg>
  )
}
