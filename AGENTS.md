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

## Natural-language TestFlight deployment command
- When the repository owner says **deploy to TestFlight**, **ship to TestFlight**, or an obvious spelling variation, treat that as authorization to complete the entire deployment workflow without asking them to translate it into CI commands.
- If the current work has a PR, get hosted `iOS CI / Build and test` green and merge it into `main`. Never deploy an unmerged commit.
- For a merged PR, use the GitHub integration or `gh` to add an exact `/testflight` comment to that merged PR. If there is no relevant PR and the request is to deploy the current `main`, manually dispatch `.github/workflows/testflight.yml` on `main`.
- Monitor the TestFlight workflow through completion. Success means the hosted archive, compliance check, signed IPA export, upload, and App Store Connect processing all pass; confirm the upload log reports processing `VALID`.
- If deployment fails, inspect hosted logs, fix the cause in a new PR, pass hosted CI, merge, and start a new TestFlight run. Do not rerun a workflow that already uploaded a build, because its build number has been consumed.
- Do not use local Xcode or local signing for this command. Never expose or move Apple credentials outside the protected GitHub `TestFlight` environment.
- Do not hand routine deployment steps back to the user. Stop only for an actual permissions, account, or Apple-service blocker that the agent cannot resolve.
