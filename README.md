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

The last two paths belong to the application repository. Rotate a leaked value rather than importing it into Terraform.

The repository also provides a stdin-only helper that verifies the secret container before creating a new version:

```bash
printf '%s' "$THESPORTSDB_API_KEY" | make set-secret SECRET=thesportsdb-api-key
printf '%s' "$YOUTUBE_API_KEY" | make set-secret SECRET=youtube-api-key

make set-secret SECRET=google-calendar-oauth \
  < ../soccer_schedule/secrets/google-calendar-oauth.json

make set-secret SECRET=google-calendar-token \
  < ../soccer_schedule/data/google-calendar-token.json
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

The application already consumes the two API-key variables. Support for the two JSON variables will be added to the application before containerization; currently, local Calendar execution still expects file paths. Clear the values from the current shell with:

```bash
unset THESPORTSDB_API_KEY YOUTUBE_API_KEY \
  GOOGLE_CALENDAR_OAUTH_JSON GOOGLE_CALENDAR_TOKEN_JSON
```

Environment variables are memory-resident but may be readable by other processes running as the same operating-system user. Avoid shell tracing and diagnostic commands that print the complete environment.
