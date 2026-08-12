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
