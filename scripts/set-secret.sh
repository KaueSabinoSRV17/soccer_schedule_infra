#!/usr/bin/env bash
set -euo pipefail

readonly ALLOWED_SECRETS=(
  "thesportsdb-api-key"
  "youtube-api-key"
  "google-calendar-oauth"
  "google-calendar-token"
)

usage() {
  cat >&2 <<'EOF'
Usage: set-secret.sh SECRET_ID < VALUE_FILE
       printf '%s' "$VALUE" | set-secret.sh SECRET_ID

Creates a new version in an existing Soccer Schedule Secret Manager secret.
The secret value must be provided through stdin and is never accepted as a
command-line argument.
EOF
}

secret_id="${1:-}"
if [[ -z "$secret_id" || $# -ne 1 ]]; then
  usage
  exit 2
fi

if [[ -t 0 ]]; then
  echo "Secret value must be piped or redirected through stdin." >&2
  usage
  exit 2
fi

allowed=false
for candidate in "${ALLOWED_SECRETS[@]}"; do
  if [[ "$secret_id" == "$candidate" ]]; then
    allowed=true
    break
  fi
done

if [[ "$allowed" != true ]]; then
  echo "Unknown Soccer Schedule secret: $secret_id" >&2
  echo "Allowed secrets: ${ALLOWED_SECRETS[*]}" >&2
  exit 2
fi

project_id="${GCP_PROJECT_ID:-}"
if [[ -z "$project_id" ]]; then
  project_id="$(gcloud config get-value project 2>/dev/null)"
fi

if [[ -z "$project_id" || "$project_id" == "(unset)" ]]; then
  echo "GCP_PROJECT_ID is required, or configure a default gcloud project." >&2
  exit 2
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required." >&2
  exit 127
fi

gcloud secrets describe "$secret_id" \
  --project "$project_id" \
  --format='none'

gcloud secrets versions add "$secret_id" \
  --project "$project_id" \
  --data-file=-
