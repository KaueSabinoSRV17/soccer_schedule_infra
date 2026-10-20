#!/usr/bin/env bash

# This file must be sourced so its exports affect the caller's shell.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this script instead of executing it:" >&2
  echo "  source scripts/load-app-secrets.sh" >&2
  exit 2
fi

_load_soccer_app_secrets() {
  local project_id="${GCP_PROJECT_ID:-}"
  local had_xtrace=false
  local sportsdb_api_key youtube_api_key calendar_oauth_json calendar_token_json

  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud is required." >&2
    return 127
  fi

  if [[ -z "$project_id" ]]; then
    project_id="$(gcloud config get-value project 2>/dev/null)"
  fi
  if [[ -z "$project_id" || "$project_id" == "(unset)" ]]; then
    echo "GCP_PROJECT_ID is required, or configure a default gcloud project." >&2
    return 2
  fi

  # Prevent values from being printed when the caller has `set -x` enabled.
  if [[ "$-" == *x* ]]; then
    had_xtrace=true
    set +x
  fi

  if ! sportsdb_api_key="$(gcloud secrets versions access latest --secret=thesportsdb-api-key --project="$project_id")" ||
    ! youtube_api_key="$(gcloud secrets versions access latest --secret=youtube-api-key --project="$project_id")" ||
    ! calendar_oauth_json="$(gcloud secrets versions access latest --secret=google-calendar-oauth --project="$project_id")" ||
    ! calendar_token_json="$(gcloud secrets versions access latest --secret=google-calendar-token --project="$project_id")"; then
    echo "Failed to load Soccer Schedule secrets; no environment variables were changed." >&2
    if [[ "$had_xtrace" == true ]]; then set -x; fi
    return 1
  fi

  export THESPORTSDB_API_KEY="$sportsdb_api_key"
  export YOUTUBE_API_KEY="$youtube_api_key"
  export GOOGLE_CALENDAR_OAUTH_JSON="$calendar_oauth_json"
  export GOOGLE_CALENDAR_TOKEN_JSON="$calendar_token_json"

  if [[ "$had_xtrace" == true ]]; then set -x; fi
  echo "Loaded Soccer Schedule secrets into the current shell environment." >&2
}

_load_soccer_app_secrets
_load_soccer_app_secrets_status=$?
unset -f _load_soccer_app_secrets
return "$_load_soccer_app_secrets_status"
