# CLAUDE.md

## GCP profile for this repo
- Project: `stattie`
- Region: `us-central1`
- Service account for automation: `stattie-codex@stattie.iam.gserviceaccount.com`
- Local key path: `~/.config/gcloud/keys/stattie-codex.json`
- gcloud config name: `stattie-sa`

## One-command setup (every new terminal/session)
```bash
bash scripts/gcp/use-stattie-sa.sh
```

After running the script, all `gcloud` commands in this repo should target the right project/region/account by default.

## Notes
- Keep all secrets in GCP Secret Manager.
- Never place raw API keys or service account JSON files in the repository.

## iOS/App Store defaults
- Bundle ID: `com.stattie.app`
- Apple Developer Team ID: `PS5W7BFTQ2`
- App Store Connect Issuer ID: `69a6de6e-8f71-47e3-e053-5b8c7c11a4d1`
