import { expect, test } from '@playwright/test'

for (const path of ['/', '/privacy', '/terms', '/support']) {
  test(`${path} renders without client errors or horizontal overflow`, async ({ page }) => {
    const errors: string[] = []
    page.on('pageerror', (error) => errors.push(error.message))
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text())
    })
    const response = await page.goto(path)
    expect(response?.status()).toBe(200)
    await expect(page.getByRole('main')).toBeVisible()
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await page.getByRole('contentinfo').scrollIntoViewIfNeeded()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)
    expect(errors).toEqual([])
  })
}

test('navigation reaches sections and App Store links agree', async ({ page, isMobile }) => {
  await page.goto('/')
  const navigation = page.getByRole('navigation', { name: 'Main navigation' })
  if (isMobile) await navigation.getByRole('button', { name: 'Toggle site navigation' }).click()
  await navigation.getByRole('link', { name: 'FAQs', exact: true }).click()
  await expect(page).toHaveURL(/#faqs$/)
  await expect(page.getByRole('heading', { name: 'Frequently asked questions' })).toBeInViewport()
  const storeLinks = page.locator('a[href*="apps.apple.com"]')
  expect(await storeLinks.count()).toBeGreaterThan(0)
  for (const link of await storeLinks.all()) {
    await expect(link).toHaveAttribute('href', 'https://apps.apple.com/app/id6758022135')
  }
})

test('reduced motion keeps reviews readable and stops the marquee', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.goto('/#reviews')
  const review = page.locator('#reviews figure').first()
  await expect(review).toBeVisible()
  await expect(review).toHaveCSS('opacity', '1')
  await expect(page.locator('.animate-marquee').first()).toHaveCSS('animation-name', 'none')
})

test('missing pages return 404 with recovery link', async ({ page }) => {
  const response = await page.goto('/missing-audit-page')
  expect(response?.status()).toBe(404)
  await page.getByRole('link', { name: 'Go back home' }).click()
  await expect(page).toHaveURL('/')
})
