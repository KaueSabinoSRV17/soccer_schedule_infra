# Existing resource imports

Set `GCP_PROJECT_ID`, authenticate, and bootstrap the state bucket first. Import only resources confirmed to exist.

## Enabled APIs

The app already uses Google Calendar API and YouTube Data API v3. Import their service usage resources if they are enabled in this project:

```bash
cd live/core
terragrunt import 'google_project_service.api["calendar-json.googleapis.com"]' \
  "$GCP_PROJECT_ID/calendar-json.googleapis.com"
terragrunt import 'google_project_service.api["youtube.googleapis.com"]' \
  "$GCP_PROJECT_ID/youtube.googleapis.com"
```

Other enabled services declared by the module may be imported with the same `<project>/<service>` form. If a service is not enabled, Terraform will enable it.

## OAuth client

The installed-app OAuth client used for Google Calendar is not managed here. The standard Google provider does not provide a general resource for an OAuth consent-screen client of this type. Keep its downloaded client JSON in Secret Manager and its refresh token in a separate secret version.

## Existing API keys

Do not place API key values in Terraform. Discover the YouTube key's resource name with:

```bash
gcloud services api-keys list --project "$GCP_PROJECT_ID"
```

Export the final segment of the resource name as the configured key name, then import the full resource name:

```bash
cd live/core
terragrunt import google_apikeys_key.youtube \
  'projects/PROJECT_NUMBER/locations/global/keys/KEY_ID_FROM_THE_RESOURCE_NAME'
```

The imported key's canonical project number, key ID, and display name are pinned in `live/core/terragrunt.hcl`; `prevent_destroy` protects it from accidental replacement. TheSportsDB key is external to Google Cloud and belongs only in Secret Manager.

## Firebase and Firestore

If Firebase is already attached to the project:

```bash
cd live/data
terragrunt import google_firebase_project.current "$GCP_PROJECT_ID"
```

If the default Firestore database already exists:

```bash
cd live/data
terragrunt import google_firestore_database.default \
  "projects/$GCP_PROJECT_ID/databases/(default)"
```
