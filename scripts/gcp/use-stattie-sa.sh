#!/usr/bin/env bash
set -euo pipefail

CONFIG_NAME="stattie-sa"
PROJECT_ID="stattie"
REGION="us-central1"
SA_EMAIL="stattie-codex@stattie.iam.gserviceaccount.com"
KEY_PATH="${HOME}/.config/gcloud/keys/stattie-codex.json"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required but not installed." >&2
  exit 1
fi

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "Missing service account key at ${KEY_PATH}" >&2
  echo "Create it with:" >&2
  echo "  gcloud iam service-accounts keys create ${KEY_PATH} --iam-account ${SA_EMAIL} --project ${PROJECT_ID}" >&2
  exit 1
fi

if ! gcloud config configurations list --format="value(name)" | grep -qx "${CONFIG_NAME}"; then
  gcloud config configurations create "${CONFIG_NAME}" --no-activate >/dev/null
fi

gcloud config configurations activate "${CONFIG_NAME}" >/dev/null
gcloud auth activate-service-account "${SA_EMAIL}" --key-file="${KEY_PATH}" --project "${PROJECT_ID}" >/dev/null
gcloud config set core/account "${SA_EMAIL}" >/dev/null
gcloud config set core/project "${PROJECT_ID}" >/dev/null
gcloud config set run/region "${REGION}" >/dev/null
gcloud auth application-default set-quota-project "${PROJECT_ID}" >/dev/null 2>&1 || true

echo "Activated gcloud config '${CONFIG_NAME}' with ${SA_EMAIL}"
echo "Project: $(gcloud config get-value core/project)"
echo "Region: $(gcloud config get-value run/region)"
