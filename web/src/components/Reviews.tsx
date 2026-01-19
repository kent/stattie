'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import clsx from 'clsx'
import { useInView } from 'framer-motion'

import { Container } from '@/components/Container'

interface Review {
  title: string
  body: string
  author: string
  rating: 1 | 2 | 3 | 4 | 5
}

const reviews: Array<Review> = [
  {
    title: 'Finally, an app that works!',
    body: 'I\'ve tried so many stat tracking apps and they\'re all too complicated. Stattie just works. I can track my son\'s games without missing any action.',
    author: 'BasketballMom2024',
    rating: 5,
  },
  {
    title: 'Perfect for youth basketball',
    body: 'Our rec league needed a simple way to track stats. Stattie is exactly what we were looking for. Easy enough for any parent to use.',
    author: 'CoachMike',
    rating: 5,
  },
  {
    title: 'Great for travel ball',
    body: 'We travel every weekend for tournaments. Love that I can track games offline and everything syncs when we get back to the hotel.',
    author: 'TravelBallDad',
    rating: 5,
  },
  {
    title: 'The sharing feature is amazing',
    body: 'Both grandparents live out of state. Now they can see their grandson\'s stats in real-time. They feel like they\'re at every game!',
    author: 'ProudMama',
    rating: 5,
  },
  {
    title: 'Worth every penny',
    body: 'No subscription? No ads? Just paid once and I own it? This is how apps should work. The developer actually respects their customers.',
    author: 'NoMoreSubscriptions',
    rating: 5,
  },
  {
    title: 'My players love seeing their stats',
    body: 'After every game I share the summary with my team. The kids are motivated to improve when they can see their numbers.',
    author: 'Coach_Thompson',
    rating: 5,
  },
  {
    title: 'Simple and effective',
    body: 'Big buttons, clean interface, no learning curve. I was tracking stats within 30 seconds of downloading.',
    author: 'BusyDadOf3',
    rating: 5,
  },
  {
    title: 'Better than the expensive ones',
    body: 'I tried apps that cost $50+ per year. Stattie does everything I need for a one-time purchase. No brainer.',
    author: 'SmartShopper',
    rating: 5,
  },
  {
    title: 'iCloud sharing is clutch',
    body: 'My wife and I both track our daughter\'s games now. We take turns and everything stays in sync perfectly.',
    author: 'TeamworkParents',
    rating: 5,
  },
  {
    title: 'Recommended to our whole league',
    body: 'I told every coach in our league about Stattie. Now half of us are using it. Makes comparing teams so easy.',
    author: 'LeagueCommissioner',
    rating: 5,
  },
  {
    title: 'Clean design, no clutter',
    body: 'I appreciate that there\'s no unnecessary features or confusing options. It does one thing and does it well.',
    author: 'MinimalistDad',
    rating: 5,
  },
  {
    title: 'Great for high school JV',
    body: 'Our JV team didn\'t have anyone tracking stats. Now I can give real feedback to my players with actual numbers.',
    author: 'JVCoach',
    rating: 5,
  },
  {
    title: 'My son tracks his own games now',
    body: 'He\'s 14 and watches film of his games while reviewing his stats. This app has helped him take his development seriously.',
    author: 'HoopsDad',
    rating: 5,
  },
  {
    title: 'Works great at tournaments',
    body: 'Five games in a weekend, no problem. Battery usage is reasonable and I never lost any data.',
    author: 'TournamentWarrior',
    rating: 5,
  },
]

function StarIcon(props: React.ComponentPropsWithoutRef<'svg'>) {
  return (
    <svg viewBox="0 0 20 20" aria-hidden="true" {...props}>
      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
    </svg>
  )
}

function StarRating({ rating }: { rating: Review['rating'] }) {
  return (
    <div className="flex">
      {[...Array(5).keys()].map((index) => (
        <StarIcon
          key={index}
          className={clsx(
            'h-5 w-5',
            rating > index ? 'fill-orange-500' : 'fill-gray-300',
          )}
        />
      ))}
    </div>
  )
}

function Review({
  title,
  body,
  author,
  rating,
  className,
  ...props
}: Omit<React.ComponentPropsWithoutRef<'figure'>, keyof Review> & Review) {
  let animationDelay = useMemo(() => {
    let possibleAnimationDelays = ['0s', '0.1s', '0.2s', '0.3s', '0.4s', '0.5s']
    return possibleAnimationDelays[
      Math.floor(Math.random() * possibleAnimationDelays.length)
    ]
  }, [])

  return (
    <figure
      className={clsx(
        'animate-fade-in rounded-3xl bg-white p-6 opacity-0 shadow-md shadow-gray-900/5',
        className,
      )}
      style={{ animationDelay }}
      {...props}
    >
      <blockquote className="text-gray-900">
        <StarRating rating={rating} />
        <p className="mt-4 text-lg/6 font-semibold before:content-['\201C'] after:content-['\201D']">
          {title}
        </p>
        <p className="mt-3 text-base/7">{body}</p>
      </blockquote>
      <figcaption className="mt-3 text-sm text-gray-600 before:content-['\2013\_']">
        {author}
      </figcaption>
    </figure>
  )
}

function splitArray<T>(array: Array<T>, numParts: number) {
  let result: Array<Array<T>> = []
  for (let i = 0; i < array.length; i++) {
    let index = i % numParts
    if (!result[index]) {
      result[index] = []
    }
    result[index].push(array[i])
  }
  return result
}

function ReviewColumn({
  reviews,
  className,
  reviewClassName,
  msPerPixel = 0,
}: {
  reviews: Array<Review>
  className?: string
  reviewClassName?: (reviewIndex: number) => string
  msPerPixel?: number
}) {
  let columnRef = useRef<React.ElementRef<'div'>>(null)
  let [columnHeight, setColumnHeight] = useState(0)
  let duration = `${columnHeight * msPerPixel}ms`

  useEffect(() => {
    if (!columnRef.current) {
      return
    }

    let resizeObserver = new window.ResizeObserver(() => {
      setColumnHeight(columnRef.current?.offsetHeight ?? 0)
    })

    resizeObserver.observe(columnRef.current)

    return () => {
      resizeObserver.disconnect()
    }
  }, [])

  return (
    <div
      ref={columnRef}
      className={clsx('animate-marquee space-y-8 py-4', className)}
      style={{ '--marquee-duration': duration } as React.CSSProperties}
    >
      {reviews.concat(reviews).map((review, reviewIndex) => (
        <Review
          key={reviewIndex}
          aria-hidden={reviewIndex >= reviews.length}
          className={reviewClassName?.(reviewIndex % reviews.length)}
          {...review}
        />
      ))}
    </div>
  )
}

function ReviewGrid() {
  let containerRef = useRef<React.ElementRef<'div'>>(null)
  let isInView = useInView(containerRef, { once: true, amount: 0.4 })
  let columns = splitArray(reviews, 3)
  let column1 = columns[0]
  let column2 = columns[1]
  let column3 = splitArray(columns[2], 2)

  return (
    <div
      ref={containerRef}
      className="relative -mx-4 mt-16 grid h-196 max-h-[150vh] grid-cols-1 items-start gap-8 overflow-hidden px-4 sm:mt-20 md:grid-cols-2 lg:grid-cols-3"
    >
      {isInView && (
        <>
          <ReviewColumn
            reviews={[...column1, ...column3.flat(), ...column2]}
            reviewClassName={(reviewIndex) =>
              clsx(
                reviewIndex >= column1.length + column3[0].length &&
                  'md:hidden',
                reviewIndex >= column1.length && 'lg:hidden',
              )
            }
            msPerPixel={10}
          />
          <ReviewColumn
            reviews={[...column2, ...column3[1]]}
            className="hidden md:block"
            reviewClassName={(reviewIndex) =>
              reviewIndex >= column2.length ? 'lg:hidden' : ''
            }
            msPerPixel={15}
          />
          <ReviewColumn
            reviews={column3.flat()}
            className="hidden lg:block"
            msPerPixel={10}
          />
        </>
      )}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-32 bg-linear-to-b from-gray-50" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-32 bg-linear-to-t from-gray-50" />
    </div>
  )
}

export function Reviews() {
  return (
    <section
      id="reviews"
      aria-labelledby="reviews-title"
      className="pt-20 pb-16 sm:pt-32 sm:pb-24"
    >
      <Container>
        <h2
          id="reviews-title"
          className="text-3xl font-medium tracking-tight text-gray-900 sm:text-center"
        >
          Trusted by basketball families everywhere.
        </h2>
        <p className="mt-2 text-lg text-gray-600 sm:text-center">
          Coaches, parents, and players are using Stattie to track their games.
        </p>
        <ReviewGrid />
      </Container>
    </section>
  )
}
