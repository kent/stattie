# Code audit and cleanup — September 7, 2026

The audit covers the shipped SwiftUI/SwiftData app, its test suite and Xcode configuration, the Next.js marketing website, GitHub CI/release workflows, and deployment scripts. The `templates/` directories are reference material and are not shipped by the `web` build; their independent dependency trees were not upgraded. Artwork, signing accounts, live user records, and legal policy text were not changed.

This is a repository code review and regression pass, not a claim that every possible defect or security issue has been eliminated.

## Findings addressed

| Priority | Finding | Result |
| --- | --- | --- |
| High | Web lockfile contained 11 vulnerable packages (9 high, 2 moderate). | Upgraded Next.js to 16.3.4 and React to 19.2.8, refreshed compatible dependencies, and verified a clean dependency audit. Regenerated optional-platform dependencies for Linux clean installs. |
| High | Player, game, membership, and profile flows silently ignored saves, sometimes dismissing on failure. | Added a shared persistence controller and error alert. Failed saves roll back and restore captured in-memory values; profile edits stay in drafts and editors dismiss only after a successful commit. Existing tracking errors use the same presenter. |
| High | Alternate game-completion paths changed a boolean without ending shifts. | Metadata edits and the player overview use the existing atomic finalization transaction. Reopening clears the completion timestamp. Failure tests exercise metadata and shift restoration. |
| High | Onboarding seed helpers saved the new profile before onboarding completed. | Catalog seeding can defer persistence; the profile and catalog now commit together. A rollback regression verifies that a failed attempt leaves no profile or sport rows. |
| Medium | Several live stat labels read only the first matching canonical row. | Shared `StatProviding` aggregation sums all attributed rows for games, players, and shifts; live shift summaries use those totals. |
| Medium | Game timer counted view ticks and lost elapsed time when ticks were suspended. | A value-type clock calculates elapsed time from timestamps and excludes pauses. UI timer events only refresh the display. |
| Medium | Shift numbering used collection count, allowing duplicates after a gap. | New numbers follow the highest remaining shift number. Negative elapsed durations are clamped to zero. |
| Medium | Active team rosters included inactive memberships. | Active roster resolution filters memberships and players, then deduplicates by player ID. |
| High | Automatic iCloud imports lacked the required background notification mode. Status monitoring started only in Settings. | Enabled background remote notifications, observe container events before opening the store, and refresh account status at launch/foreground/account changes. Native SwiftData remains the only sync engine. |
| High | Timestamp-based achievement mirroring could discard progress earned concurrently; reading preferences could create or dirty cloud rows. | Achievement snapshots merge by union without overwriting other devices’ snapshots, preserve legacy points, and keep a scoped local retry cache. Onboarding follows the synced User record; local navigation state is observable and no longer mirrored to cloud settings. Existing schema types remain intact. |
| Medium | Sync UI invented percentages, claimed all phases completed after one event, and offered a button that could not force a sync. | Replaced the pipeline and retry timer with a simple automatic-sync status. Track actual operations by event ID; a successful download cannot clear a failed upload. Setup does not count as transferred data, and account changes clear stale activity. |
| Medium | Photo resizing inherited device display scale, exceeding the advertised pixel cap. | Image rendering explicitly uses scale 1; regression coverage checks actual pixel dimensions and idempotence. |
| Medium | Generic sport list labels could disagree with their values (e.g. golf putts labeled as fairways). | Label selection now follows the same catalog priority as score selection. |
| Medium | Web lint had no configuration or hosted enforcement; newer React checks rejected reading refs during render. | Added flat ESLint configuration, explicit type checks, production builds, and desktop/mobile Playwright coverage in Web CI. Feature direction is derived during the selection event. |
| Medium | Mobile footer could overflow; navigation was duplicated; motion preferences were not honored consistently. | Shared navigation/site constants, CSS hover states, wrapping footer links, skip link, reduced-motion provider/CSS, deterministic review animation, and accessible star labels. |
| Medium | A manual screenshot utility interpolated shell values into Ruby source. | Arguments are passed as data to a quoted Ruby heredoc; no credentials were read or executed during this audit. |
| Low | Stat mutations, chart selection, sport creation, and schema lists had parallel implementations. | One mutation/undo representation, metric selector, sport-creation helper, and production/test schema. |
| Low | Large view files mixed tracking with independent sheets and unused screens. | Extracted shift editor, tracking components, score sheets, and player overview. Removed the unreachable older shift tracker, unused lock manager, and widgets with no production call sites. |
| Low | Notification state mixed callback queues with async work; review prompts could bypass their cooldown. | Notification and review managers are main-actor isolated, use current platform APIs with an iOS 17 fallback where needed, and honor the cooldown. The explicit Settings review button opens the App Store review page. |
| Low | Date formatting repeatedly constructed formatters; persistence diagnostics used prints or empty catches. | Updated relevant dates to Foundation format styles and moved service diagnostics to structured OSLog logging. |
| Low | “This Month” chart filter meant a rolling month. | The filter now starts at the current calendar month. |

## Validation and release

- Local web checks: ESLint with zero warnings, TypeScript route generation/checking, optimized production build, and 14 Playwright cases across desktop/mobile Chromium.
- Dependency validation: `npm audit` reports zero vulnerabilities; clean npm installation and Linux/x64 dependency resolution checked.
- Hosted checks: Web CI and iOS CI are required to pass on the final PR revision before merging.
- Added iOS regression cases cover save failure/retry, completion/reopen/rollback, elapsed time and pauses, shift numbering, negative durations, generic sport labels, inactive memberships, aggregate displays, and photo pixel limits.
- Xcode project and shell syntax checked. iOS builds/tests and all signing/upload work run on GitHub-hosted macOS, never local Xcode.
- Web is deployed to Cloud Run after verification. One TestFlight workflow will run from the final merged commit; completion requires App Store Connect processing `VALID`.

## Compatibility decisions and remaining work

- Keep Swift 5 language mode and iOS 17 support. Main-actor improvements are incremental; a complete Swift 6 strict-concurrency migration still needs dedicated coverage of app state, CloudKit observers, and singleton access. Changing the compiler flag alone would not establish correctness.
- Keep persisted legacy SwiftData fields and `ShiftStat` migration support. Removing stored fields or changing CloudKit schema deserves a separate migration plan and tests with existing user stores.
- ESLint 10 currently fails in the React plugin bundled by this Next.js configuration (`context.getFilename` API removal). The working ESLint 9.39.5 configuration remains pinned to major 9 until that upstream compatibility is resolved. TypeScript stays on the compatible 5.9 line; major-version changes are not required merely because a newer version exists.
- CloudKit status reports observed activity, never promises every record is uploaded. The unsigned hosted suite exercises event handling, imported-profile resolution, concurrent achievement merging, legacy migration, and offline cache recovery; live two-device transfers and Apple account switching still require signed-device integration testing. Native CloudKit decides transfer timing.
- Some sheet transitions still use short delayed dispatches. A future explicit presentation state machine and iOS UI automation would provide stronger coverage than unit tests alone.
- Bootstrap still terminates if both cloud-backed and local persistent stores fail to open. A non-destructive recovery screen needs a separate data-recovery design; automatically deleting a user's store is not an acceptable cleanup.
- Website testimonials are static content with no provenance attached in the repository. Authenticity was not established by this code audit.
- Reference templates and old planning/deployment documents may contain stale instructions. The active repository instructions and hosted workflows were used for this release.

## Guidance used

- [Next.js 16 upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-16) and [ESLint configuration](https://nextjs.org/docs/app/api-reference/config/eslint): supported runtime, standalone lint command, and flat configuration.
- [Swift incremental concurrency adoption](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/incrementaladoption/): explicit isolation and staged migration.
- [Apple date format styles](https://developer.apple.com/documentation/foundation/date/formatstyle) and [requesting App Store reviews](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews): current platform APIs with deployment-target compatibility.

- [Apple automatic SwiftData sync](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) and [CloudKit container events](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/eventchangednotification): required background capability, native automatic syncing, and truthful activity monitoring.
