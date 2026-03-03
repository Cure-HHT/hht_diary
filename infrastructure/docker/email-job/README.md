# email-job

Cloud Run Job for sending test emails via the Gmail API using Workload Identity Federation and domain-wide delegation. Replicates the auth flow from the portal-server `EmailService` (signJwt approach).

## Architecture

1. Obtains an ADC access token (metadata server on Cloud Run, or `gcloud auth` locally).
2. Signs a JWT with domain-wide delegation (`sub` claim = `EMAIL_SENDER`).
3. Exchanges the signed JWT for a Gmail-scoped access token.
4. Sends an email via the Gmail API `messages.send` endpoint.

## Environment Variables

| Variable | Required | Default | Source | Description |
| --- | --- | --- | --- | --- |
| `EMAIL_SVC_ACCT` | **Yes** | — | Cloud Run env var | Gmail service account with domain-wide delegation |
| `EMAIL_SENDER` | **Yes** | — | Cloud Run env var | Workspace email address to send from (e.g., `support@anspar.org`) |
| `RECIPIENT_EMAIL` | No | DevOps Slack channel email | Cloud Run env var | Override recipient address |
| `SUBJECT` | No | `[Cloud Run] Test email from ${GCP_PROJECT_ID}` | Cloud Run env var | Override email subject line |
| `GCP_PROJECT_ID` | No | — | Cloud Run metadata or env | Used in the default subject line for context |

Authentication is via ADC (metadata server on Cloud Run, or `gcloud auth` locally). No Doppler or Secret Manager calls.

## Usage

```bash
# Build
docker build -t email-job infrastructure/docker/email-job/

# Run locally (requires gcloud auth)
docker run --rm \
  -e EMAIL_SVC_ACCT=org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com \
  -e EMAIL_SENDER=support@anspar.org \
  -v "$HOME/.config/gcloud:/home/appuser/.config/gcloud:ro" \
  email-job
```
