import clsx from 'clsx'

export function AppStoreLink({
  color = 'black',
}: {
  color?: 'black' | 'white'
}) {
  return (
    <span
      role="status"
      aria-label="App Store availability pending"
      className={clsx(
        'inline-flex min-h-10 items-center rounded-lg px-5 py-2 text-sm font-semibold',
        color === 'black'
          ? 'bg-gray-800 text-white'
          : 'bg-white text-gray-900',
      )}
    >
      App Store availability pending
    </span>
  )
}
