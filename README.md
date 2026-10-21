# Soccer Schedule infrastructure

Terragrunt-managed Google Cloud infrastructure for the Soccer Schedule collector and its future mobile decision workflow.

## Layout

```text
bootstrap/                 # one-time remote-state bucket
modules/                   # reusable Terraform modules
live/<component>/          # deployable Terragrunt units
```

The live stack declares:

- `core`: APIs, Artifact Registry, service accounts, IAM and secret containers;
- `publishing`: GitHub Actions variables, Workload Identity Federation and repository-scoped image publishing IAM;
- `data`: Firebase activation and the Firestore database;
- `collector`: the Cloud Run job and its 06:00 `America/Sao_Paulo` scheduler;
- `api`: the Cloud Run service for mobile conflict decisions.

Compute units are disabled initially because the application does not yet publish a container image or expose an HTTP API. Enable them in `live/config.hcl` after the app image exists.

## Prerequisites

```bash
export GCP_PROJECT_ID='your-project-id'
export GCP_REGION='southamerica-east1'
export GOOGLE_APPLICATION_CREDENTIALS='/path/to/terraform-service-account.json'
```

Application Default Credentials (`gcloud auth application-default login`) can be used instead of a key file. Do not commit credentials.

## Bootstrap remote state

The state bucket cannot manage its own backend. Create it once with local Terraform state:

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="region=$GCP_REGION"
```

Then initialize and inspect the stack:

```bash
terragrunt run --all init
terragrunt run --all plan
```

Terragrunt 1.x uses `run --all`; older releases use `run-all`.

## Makefile commands

Run a command against every live unit by omitting `MODULE`:

```bash
make plan
make apply
make state-list
```

Target one unit with `MODULE`:

```bash
make plan MODULE=core
make apply MODULE=collector
make state-list MODULE=data
make destroy MODULE=api
```

Additional helpers are available through `make help`, including `init`, `validate`, `fmt`, and `units`. Apply uses `-auto-approve` by default; destroy remains interactive, including all-unit runs.

Pass additional OpenTofu arguments with `ARGS`. For example, upgrade provider selections across every unit with:

```bash
make init ARGS=-upgrade
```

The same mechanism works for an individual unit or other commands:

```bash
make init MODULE=data ARGS=-upgrade
make plan MODULE=core ARGS="-lock-timeout=30s"
```

## Existing-resource imports

See [IMPORTS.md](IMPORTS.md). Run imports before the first apply when a declared resource already exists.

## Secret values

Terraform creates only secret containers. Add values outside Terraform so plaintext is never written into state:

```bash
printf '%s' "$THESPORTSDB_API_KEY" | \
  gcloud secrets versions add thesportsdb-api-key --data-file=- --project "$GCP_PROJECT_ID"

printf '%s' "$YOUTUBE_API_KEY" | \
  gcloud secrets versions add youtube-api-key --data-file=- --project "$GCP_PROJECT_ID"

gcloud secrets versions add google-calendar-oauth --data-file=secrets/google-calendar-oauth.json --project "$GCP_PROJECT_ID"
gcloud secrets versions add google-calendar-token --data-file=data/google-calendar-token.json --project "$GCP_PROJECT_ID"
```

The last two paths belong to the application repository (`../soccer_schedule_function` locally). The collector only mounts `google-calendar-token`; the OAuth client secret container remains available for the local authorization flow. Rotate a leaked value rather than importing it into Terraform.

The repository also provides a stdin-only helper that verifies the secret container before creating a new version:

```bash
printf '%s' "$THESPORTSDB_API_KEY" | make set-secret SECRET=thesportsdb-api-key
printf '%s' "$YOUTUBE_API_KEY" | make set-secret SECRET=youtube-api-key

make set-secret SECRET=google-calendar-oauth \
  < ../soccer_schedule_function/secrets/google-calendar-oauth.json

make set-secret SECRET=google-calendar-token \
  < ../soccer_schedule_function/data/google-calendar-token.json
```

The value is not accepted as a command-line argument, printed by the script, or stored in Terraform state. Re-running the command creates a new secret version.

### Load application secrets into the current shell

Source the loader to fetch all four latest secret versions directly into environment variables without creating temporary files:

```bash
source scripts/load-app-secrets.sh
```

It exports:

```text
THESPORTSDB_API_KEY
YOUTUBE_API_KEY
GOOGLE_CALENDAR_OAUTH_JSON
GOOGLE_CALENDAR_TOKEN_JSON
```

The application consumes the two API-key variables. Calendar execution reads the token JSON from the file path in `GOOGLE_CALENDAR_TOKEN`; loading the JSON variables above does not configure that path. The collector mounts that file directly from Secret Manager. Clear the loaded values from the current shell with:

```bash
unset THESPORTSDB_API_KEY YOUTUBE_API_KEY \
  GOOGLE_CALENDAR_OAUTH_JSON GOOGLE_CALENDAR_TOKEN_JSON
```

Environment variables are memory-resident but may be readable by other processes running as the same operating-system user. Avoid shell tracing and diagnostic commands that print the complete environment.

## GitHub image publishing and collector deployment

The existing app workflow builds and tests the container, then pushes both the full commit SHA tag and `latest` on pushes to `main` or manual runs on `main`. Terraform manages its authentication and repository variables through `live/publishing`; it does not manage the application workflow file or build the image.

Apply `core` before `publishing` to enable the required APIs and create the registry. The GitHub provider uses `GITHUB_TOKEN`; provide a token with repository Variables read/write permission and repository access. The existing repository is not recreated or taken over by Terraform. The numeric owner and repository IDs in `live/config.hcl` were checked against GitHub and must be updated if you change the target repository.

```bash
make apply MODULE=core
# Authenticate the GitHub provider without writing a token to configuration or state:
export GITHUB_TOKEN="$(gh auth token)"
make init MODULE=publishing
make plan MODULE=publishing
make apply MODULE=publishing
unset GITHUB_TOKEN
```

The publishing unit manages `GCP_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `GCP_REGION`, and `GAR_REPOSITORY`. If variables already exist, import them before applying, for example from `live/publishing`:

```bash
terragrunt run -- import 'github_actions_variable.publishing["GCP_PROJECT_ID"]' soccer-schedule:GCP_PROJECT_ID
```

The publisher can write only to this Artifact Registry repository. Federation accepts only the configured numeric repository and owner IDs, the configured branch, and `push`/`workflow_dispatch` events. No service account key is created.

After the app's container setup is committed and pushed, trigger the build if necessary and wait for success:

```bash
gh workflow run container.yml --repo KaueSabinoSRV17/soccer-schedule --ref main
gh run list --repo KaueSabinoSRV17/soccer-schedule --workflow container.yml
# Use the default :latest image published by CI.
unset SOCCER_IMAGE
```

Populate the two API-key secrets and, in OAuth mode, the Calendar token secret using the commands above before enabling the collector. Calendar authorization and token generation happen in the application outside Terraform. Set `deploy_job = true` in `live/config.hcl`. The image defaults to the registry’s `:latest` tag; no SHA export is needed. Then:

```bash
make plan MODULE=collector
make apply MODULE=collector
gcloud run jobs execute soccer-schedule-daily \
  --project "$GCP_PROJECT_ID" --region "${GCP_REGION:-southamerica-east1}" --wait
gcloud logging read 'resource.type="cloud_run_job" AND resource.labels.job_name="soccer-schedule-daily"' \
  --project "$GCP_PROJECT_ID" --limit 50
```

Verify the resulting Calendar events in the authorized user's calendar. The collector runs `--full-calendar-sync`, preserving all unfinished matches, including overlaps. The scheduler invokes it daily at 06:00 São Paulo time. The configured image follows `:latest`, so the selected code can change when CI publishes a new image without a Terraform configuration change. For an explicit rollback or fixed version, set `SOCCER_IMAGE` to a full commit-SHA tag or image digest before planning and applying; unset it to return to `:latest`.

## Calendar authentication and automatic refresh

The existing OAuth app already supplies its refresh token to Google's OAuth client, which refreshes access tokens automatically. Terraform does not run the consent flow or replace expired/revoked refresh tokens. External OAuth applications in Testing can receive refresh tokens that expire after seven days when Calendar scopes are requested; moving to Production addresses that testing limit but does not prevent revocation. See [Google's token expiration documentation](https://developers.google.com/identity/protocols/oauth2#expiration).

For a dedicated soccer calendar, use the job's existing runtime service account through [Cloud Run Application Default Credentials](https://docs.cloud.google.com/run/docs/securing/service-identity). The infrastructure supports `calendar_auth_mode = "service_account"`; this omits the user-token mount and token-path variable. OAuth remains the default until the application is migrated. Existing Calendar secret containers and IAM bindings are retained so migration does not delete credentials.

The companion app patch is [patches/calendar-service-account.patch](patches/calendar-service-account.patch). It adds ADC with the `calendar.events` scope when `GOOGLE_CALENDAR_AUTH_MODE=service_account`, keeps the existing OAuth flow by default, rejects invalid modes and `primary` in service-account mode, and includes an authentication regression test. Apply it in the application repository, test, commit, and publish a new image:

```bash
git -C ../soccer_schedule_function apply ../soccer_schedule_infra/patches/calendar-service-account.patch
npm --prefix ../soccer_schedule_function test
```

Complete the one-time Calendar setup as the calendar owner:

1. Create a dedicated soccer calendar in Google Calendar.
2. Read the runtime email with `terragrunt --working-dir live/core run -- output -raw runtime_email`.
3. Share that calendar with this email using **Make changes to events** (`writer`). Cloud IAM roles do not grant Calendar access. Workspace sharing policies may restrict this; see [Calendar sharing](https://developers.google.com/workspace/calendar/api/concepts/sharing).
4. Copy the **Calendar ID** from **Settings → Integrate calendar**. Set `calendar_auth_mode = "service_account"` and `calendar_id = "<copied-id>"` in `live/config.hcl`, or supply the ID through `GOOGLE_CALENDAR_ID`.
5. Deploy the newly published image using the collector instructions above, execute once, and verify events in the dedicated calendar.

No service-account key, user refresh token, domain-wide delegation, or Token Creator role is required for this path. Google manages the attached service account's short-lived credentials. Calendar creation/sharing remains a one-time owner action here; the standard Google provider does not manage Calendar ACLs. Do not enable service-account mode with an older image that only reads OAuth token files.
