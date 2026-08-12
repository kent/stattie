#!/usr/bin/env bash
set -euo pipefail

# Optional env file (non-secret defaults + local secret paths).
ENV_FILE="${APPSTORE_ENV_FILE:-scripts/appstore/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# Usage:
# APP_STORE_CONNECT_ISSUER_ID=... \
# APP_STORE_CONNECT_KEY_ID=... \
# APP_STORE_CONNECT_KEY_PATH=/abs/path/AuthKey_XXX.p8 \
# scripts/appstore/upload_screenshots.sh assets/app-store/2026-03-02/upload 1.0

SCREENSHOTS_PATH="${1:-assets/app-store/2026-03-02/upload}"
APP_VERSION="${2:-1.0}"
APP_IDENTIFIER="${APP_IDENTIFIER:-com.stattie.app}"

: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"
: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_KEY_PATH:?APP_STORE_CONNECT_KEY_PATH is required}"

if ! command -v fastlane >/dev/null 2>&1; then
  echo "fastlane is not installed. Install with: brew install fastlane" >&2
  exit 1
fi

if [[ ! -d "$SCREENSHOTS_PATH" ]]; then
  echo "Screenshots path does not exist: $SCREENSHOTS_PATH" >&2
  exit 1
fi

if [[ ! -f "$APP_STORE_CONNECT_KEY_PATH" ]]; then
  echo "Key file does not exist: $APP_STORE_CONNECT_KEY_PATH" >&2
  exit 1
fi

API_KEY_JSON="$(mktemp /tmp/asc_api_key.XXXXXX.json)"
trap 'rm -f "$API_KEY_JSON"' EXIT

ruby <<RUBY
require 'json'
key = File.read('${APP_STORE_CONNECT_KEY_PATH}')
json = {
  key_id: '${APP_STORE_CONNECT_KEY_ID}',
  issuer_id: '${APP_STORE_CONNECT_ISSUER_ID}',
  key: key,
  in_house: false
}
File.write('${API_KEY_JSON}', JSON.pretty_generate(json))
RUBY

FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 \
fastlane deliver \
  --api_key_path "$API_KEY_JSON" \
  --app_identifier "$APP_IDENTIFIER" \
  --platform ios \
  --app_version "$APP_VERSION" \
  --screenshots_path "$SCREENSHOTS_PATH" \
  --skip_binary_upload true \
  --skip_metadata true \
  --overwrite_screenshots true \
  --force true \
  --run_precheck_before_submit false \
  --ignore_language_directory_validation true
