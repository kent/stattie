# TestFlight deployment blockers (2026-08-30)

**Goal:** Ship a new TestFlight build from PR [#1](https://github.com/kent/stattie/pull/1) (`cursor/player-team-membership-eddb` → `main`).

**Prepared in repo:** marketing version **1.0.2**, build **5** (was 1.0.1 / 4).

**Result:** Could **not** archive or upload to TestFlight from this Cloud Agent environment.

---

## Errors / blockers encountered

1. **No macOS / Xcode on this agent**
   - Host: Linux (`uname` reports Linux x86_64).
   - `xcodebuild` is not installed / not available.
   - iOS archives (`.ipa` / `.xcarchive`) cannot be produced here.

2. **No Fastlane / upload toolchain**
   - `fastlane` is not installed.
   - Repo has App Store metadata + `scripts/appstore/upload_screenshots.sh`, but **no Fastfile lane** for `build` / `upload_to_testflight` / `pilot`.
   - Existing script only uploads screenshots (`--skip_binary_upload true`).

3. **App Store Connect API private key not available in this environment**
   - Expected local path from `scripts/appstore/.env.example`:
     - `/Users/kent/.keys/AuthKey_UWS2742H66.p8`
   - That path does not exist on this VM.
   - No `AuthKey_*.p8` found under `/home`, `/opt`, or `/tmp`.
   - No App Store Connect env vars were set (`APP_STORE_CONNECT_*`, `ASC_*`, `FASTLANE_*`).
   - `scripts/appstore/.env` is not present (only `.env.example`).

4. **No GCP / Secret Manager access from this shell**
   - `gcloud` is not installed, so secrets cannot be pulled via `scripts/gcp/use-stattie-sa.sh`.

5. **No GitHub Actions / CI macOS build workflow**
   - No `.github/workflows` present to archive and upload on a Mac runner.

---

## What is needed to complete TestFlight upload

Run these on a **Mac with Xcode**, signed into team `PS5W7BFTQ2`, with the ASC API key available.

### Credentials / files
- App Store Connect API key: `AuthKey_UWS2742H66.p8` (key id `UWS2742H66`)
- Issuer ID: `69a6de6e-8f71-47e3-e053-5b8c7c11a4d1` (from AGENTS.md / `.env.example`)
- Local env file (do **not** commit): copy `scripts/appstore/.env.example` → `scripts/appstore/.env` and set `APP_STORE_CONNECT_KEY_PATH` to the real `.p8` path
- Apple signing: automatic signing for `com.stattie.app`, team `PS5W7BFTQ2`

### Suggested local commands
```bash
git checkout cursor/player-team-membership-eddb
# or merge/rebase onto main after PR merge

# Archive + upload (Xcode UI or CLI). Example CLI shape:
xcodebuild -scheme Stattie -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Stattie.xcarchive archive

xcodebuild -exportArchive \
  -archivePath build/Stattie.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Then upload the IPA via Transporter, Organizer, or:
# xcrun altool --upload-app ...   (or Fastlane pilot once a Fastfile exists)
```

### App identity for this candidate
| Item | Value |
|---|---|
| Bundle ID | `com.stattie.app` |
| App Store Connect app ID | `6758022135` |
| Marketing version | `1.0.2` |
| Build | `5` |
| PR | https://github.com/kent/stattie/pull/1 |

### Optional follow-ups to unblock future agents
1. Add a macOS CI workflow (GitHub Actions `macos-latest`) that archives and uploads with a stored ASC `.p8` secret.
2. Add a Fastlane `beta` / `testflight` lane (build + `upload_to_testflight`).
3. Store the ASC `.p8` + key id in a secret store the agent can access (e.g. GCP Secret Manager), **never in git**.
4. Provide a Cloud Agent environment that includes Xcode, or a self-hosted Mac runner.

---

## PR status

- Pull request is open **against `main`**: https://github.com/kent/stattie/pull/1
- Branch is up to date with `origin/main` (no additional merge required at time of writing).
