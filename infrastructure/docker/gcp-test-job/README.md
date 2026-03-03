# gcp-test-job

Diagnostic Cloud Run Job that validates the service account can read `DOPPLER_TOKEN` from GCP Secret Manager and that the Doppler configuration is correct for the target environment.

## What It Tests

1. Fetches `DOPPLER_TOKEN` from Secret Manager (verifies `secretmanager.versions.access` permission).
2. Uses the Doppler CLI to read `GCP_PROJECT_ID` from the specified Doppler project/config.
3. Validates that `GCP_PROJECT_ID` ends with `DOPPLER_CONFIG_NAME` (catches environment mismatches).

## Environment Variables

| Variable | Required | Default | Source | Description |
| --- | --- | --- | --- | --- |
| `DOPPLER_PROJECT_ID` | **Yes** | — | Cloud Run env var | Doppler project to validate (e.g., `hht-diary`) |
| `DOPPLER_CONFIG_NAME` | **Yes** | — | Cloud Run env var | Doppler config to validate (e.g., `dev`, `qa`, `uat`) |

`DOPPLER_TOKEN` is not passed in — it is fetched from Secret Manager during execution.

## Usage

```bash
# Build
docker build -t gcp-test-job infrastructure/docker/gcp-test-job/

# Deploy as a Cloud Run Job
gcloud run jobs create gcp-test-job \
  --image=gcp-test-job \
  --region=europe-west9 \
  --set-env-vars="DOPPLER_PROJECT_ID=hht-diary,DOPPLER_CONFIG_NAME=dev"

# Execute
gcloud run jobs execute gcp-test-job --region=europe-west9
```
