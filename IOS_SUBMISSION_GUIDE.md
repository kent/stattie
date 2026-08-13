# Stattie iOS App Store Submission Guide

This guide records the current release identifiers, uploaded build, and remaining App Store release checks.

## Release source of truth

| Item | Value |
|---|---|
| App name | Stattie |
| Bundle ID | `com.stattie.app` |
| Apple Developer Team ID | `PS5W7BFTQ2` |
| iCloud container | `iCloud.com.stattie.app` |
| App Store Connect app ID | `6758022135` |
| App Store URL | <https://apps.apple.com/app/id6758022135> |
| Website | <https://www.stattie.com> |
| Privacy policy | <https://www.stattie.com/privacy> |
| Support | <https://www.stattie.com/support> |
| Review contact | Kent Fenwick, `kent.fenwick@gmail.com`, `+1 416-788-1373` |
| Release version | `1.0.1` (build `2`) |
| Minimum iOS version | iOS 17.0 |

The bundle ID and team ID above agree with the Xcode signing configuration and the exported archive. The numeric app ID was verified against the App Store Connect API for `com.stattie.app` on August 12, 2026.

> **Free release configured:** The base App Store price is USD 0.00, with automatic equalized pricing across territories. Version 1.0.1 build 2 is processed as `VALID`; the 1.0.1 store-version record, metadata, review contact, and screenshots were uploaded on August 12, 2026. Confirm App Store validation and submit the version for review before restoring public download links.

## App Review contact

The App Review contact is Kent Fenwick, `kent.fenwick@gmail.com`, `+1 416-788-1373`. The phone number is verified against the same contact on released apps in this App Store Connect account and is stored in `fastlane/metadata/review_information/contact_phone.txt`.

## Privacy and product behavior

- Core player, team, game, and preference data is stored on-device.
- Private sync through the user's own iCloud account is optional.
- Coaching recommendations are generated on-device. No player or game data is sent to an AI provider.
- Stattie has no advertising SDK, cross-app tracking, or developer analytics.
- Ordinary user-initiated exports use the iOS share sheet. The app does not ship CKShare/team-invite collaboration.
- The App Store privacy answer remains **Data Not Collected** so long as no new server analytics, accounts, support upload, or remote processing is added.

If any of those facts change, update all of the following before upload:

- `Stattie/PrivacyInfo.xcprivacy`
- <https://www.stattie.com/privacy>
- `fastlane/app_privacy_details.json`
- the App Privacy answers in App Store Connect

The privacy manifest declares no tracking or collected data and declares `UserDefaults` access for app preferences using required-reason code `CA92.1`.

## Required Xcode integration checks

The project generates its final Info.plist while also referencing `Stattie/Info.plist`. The target build settings currently mirror the export-compliance value, and the privacy manifest is in Copy Bundle Resources. Before every archive, confirm the built product still contains both settings below:

1. `ITSAppUsesNonExemptEncryption = NO`.
2. `PrivacyInfo.xcprivacy` appears at the root of the built `.app` bundle.

Do not restore the old `cloudkit-iCloud.com.stattie.app` custom URL scheme. Private CloudKit sync uses the iCloud entitlement and does not require that CKShare URL scheme.

Useful archive checks:

```bash
# Point APP_PATH at the archived app.
plutil -p "$APP_PATH/Info.plist" | grep ITSAppUsesNonExemptEncryption
plutil -lint "$APP_PATH/PrivacyInfo.xcprivacy"
test -f "$APP_PATH/PrivacyInfo.xcprivacy"
```

## Website and metadata checks

The following URLs must return HTTP 200 before metadata is submitted:

```bash
curl -fsS -o /dev/null https://www.stattie.com/
curl -fsS -o /dev/null https://www.stattie.com/privacy
curl -fsS -o /dev/null https://www.stattie.com/support
curl -fsS -o /dev/null https://www.stattie.com/terms
```

Fastlane metadata uses the canonical `www.stattie.com` URLs. Do not use `stattie.app`: that domain and its former support email addresses are not configured source-of-truth identifiers for this project.

## App Review notes

No login or demo account is required.

1. Add a player.
2. Create a game for that player.
3. Record several stats.
4. End the game and inspect the summary.
5. Review on-device coaching focus and player trends.

Private iCloud sync is optional for this review path. Reviewers do not need a second account, a collaboration invite, an API key, or a proxy token.

## Submission checklist

### Before archiving

- [x] Confirm the real App Review phone number in metadata and App Store Connect.
- [ ] Confirm `com.stattie.app` and team `PS5W7BFTQ2` in Release signing settings.
- [ ] Confirm the production iCloud container is `iCloud.com.stattie.app`.
- [ ] Confirm the privacy manifest and export-compliance key are in the built app.
- [ ] Run a clean Release build and all configured tests.
- [ ] Test first launch, local save, game finalization, undo, summaries, on-device coaching, offline use, iCloud recovery, Settings links, and the share sheet on a physical device.
- [ ] Confirm no placeholder URLs, identifiers, contacts, demo data, or remote-AI claims remain.
- [ ] Confirm screenshots match the current UI and claims. Submission assets are documented in `assets/app-store/2026-03-02/README.md`.

### App Store Connect

- [ ] Select the existing Stattie record (`6758022135`) rather than creating another app.
- [ ] Confirm privacy URL: `https://www.stattie.com/privacy`.
- [ ] Confirm support URL: `https://www.stattie.com/support`.
- [ ] Confirm marketing URL: `https://www.stattie.com`.
- [ ] Confirm App Review name, email, and real phone number.
- [ ] Confirm the privacy label still matches shipped behavior.
- [ ] Confirm encryption/export-compliance answers match the built Info.plist.
- [ ] Verify price, territories, availability date, screenshots, age rating, and release method directly in App Store Connect; do not infer them from this repository.

### Upload

Build 2, metadata, review information, and screenshots have been uploaded successfully. API keys and `.p8` files must remain outside the repository. Re-run App Store Connect validation and perform a TestFlight smoke test before review submission.

## Post-release

- Verify <https://apps.apple.com/app/id6758022135> in every intended storefront.
- Verify the website's App Store buttons open the product page.
- Verify privacy, terms, and support links from the production app.
- Update version-specific screenshots and release notes without changing the identifiers in the source-of-truth table.
