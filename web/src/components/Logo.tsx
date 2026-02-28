import Image from 'next/image'
import clsx from 'clsx'

export function Logomark({
  className,
  alt = 'Stattie logo',
  priority = false,
}: {
  className?: string
  alt?: string
  priority?: boolean
}) {
  return (
    <Image
      src="/stattie-logo.png"
      alt={alt}
      width={40}
      height={40}
      priority={priority}
      className={clsx('h-10 w-10 rounded-xl', className)}
    />
  )
}

export function Logo({
  className,
  textClassName,
}: {
  className?: string
  textClassName?: string
}) {
  return (
    <span className={clsx('inline-flex items-center gap-3', className)}>
      <Logomark priority />
      <span
        className={clsx(
          'text-2xl font-semibold tracking-tight text-gray-900',
          textClassName,
        )}
      >
        Stattie
      </span>
    </span>
  )
}
