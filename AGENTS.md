# AGENTS.md

## Project defaults
- GCP project: `stattie`
- Region: `us-central1`
- Primary Cloud Run service: `stattie-web`
- Automation service account: `stattie-codex@stattie.iam.gserviceaccount.com`

## Required GCP auth flow for agents
Before any `gcloud` command, run:

```bash
bash scripts/gcp/use-stattie-sa.sh
```

This activates a dedicated gcloud configuration (`stattie-sa`) and uses the local key at:
- `~/.config/gcloud/keys/stattie-codex.json`

Do not commit service account keys to git.

## Typical commands
```bash
bash scripts/gcp/use-stattie-sa.sh
gcloud run services list
gcloud run deploy stattie-web --region us-central1 --source web --allow-unauthenticated
```

## iOS/App Store defaults
- Bundle ID: `com.stattie.app`
- Apple Developer Team ID: `PS5W7BFTQ2`
- App Store Connect Issuer ID: `69a6de6e-8f71-47e3-e053-5b8c7c11a4d1`

## Cursor Cloud and TestFlight
- Cursor Cloud agents run on Linux and cannot run Xcode or produce an iOS archive.
- Use `.github/workflows/ios-ci.yml` for pull-request tests on a GitHub macOS runner.
- TestFlight credentials belong only in the GitHub `TestFlight` environment. Never add Apple `.p8`, `.p12`, or provisioning-profile contents to Cursor secrets, commits, PR bodies, comments, or logs.
- TestFlight deployments must build a commit already merged into `main`. Trigger one by commenting exactly `/testflight` on the merged PR, or use the workflow's manual `main`-branch dispatch as a fallback.
- The deployment workflow assigns monotonically increasing build numbers. Feature agents should update `MARKETING_VERSION` when the public version changes, but should not guess or reuse a TestFlight build number.
- See `MOBILE_TESTFLIGHT.md` for the phone workflow and recovery steps.
