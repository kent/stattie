import Link from 'next/link'

import { navigationLinks } from '@/lib/site'

export function NavLinks() {
  return navigationLinks.map(({ label, href }) => (
    <Link
      key={href}
      href={href}
      className="relative -mx-3 -my-2 rounded-lg px-3 py-2 text-sm text-gray-700 transition-colors hover:bg-gray-100 hover:text-gray-900 focus-visible:bg-gray-100"
    >
      {label}
    </Link>
  ))
}
