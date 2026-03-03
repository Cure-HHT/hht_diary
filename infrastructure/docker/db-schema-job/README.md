# db-schema-job (deploy-db)

Cloud Run Job that deploys database schema to Cloud SQL PostgreSQL for a single sponsor/environment. Optionally resets Identity Platform users.

## Architecture

1. If `DOPPLER_PROJECT_ID` is set, fetches `DOPPLER_TOKEN` from GCP Secret Manager, then re-executes under `doppler run` to inject all secrets.
2. Downloads schema SQL and seed data from GCS.
3. Drops and recreates the target database, applies schema, then seed data.
4. Optionally batch-deletes and re-seeds Identity Platform users (`RESET_IDS=true`).

## Environment Variables

| Variable | Required | Default | Source | Description |
| --- | --- | --- | --- | --- |
| `DOPPLER_PROJECT_ID` | No | — | Cloud Run env var | If set, enables Doppler bootstrap path |
| `DOPPLER_CONFIG_NAME` | If Doppler | — | Cloud Run env var | Doppler environment config name |
| `DOPPLER_TOKEN` | If Doppler | — | Fetched from Secret Manager | Doppler auth token |
| `DB_HOST` | **Yes** | — | Doppler or direct env var | PostgreSQL host |
| `DB_PORT` | No | `5432` | Doppler or direct | PostgreSQL port |
| `DB_NAME` | **Yes** | — | Doppler or direct | Database name to create/reset |
| `DB_USER` | **Yes** | — | Doppler or direct | PostgreSQL user (needs superuser for DROP/CREATE) |
| `DB_PASSWORD` | **Yes** | — | Doppler or direct | PostgreSQL password |
| `SCHEMA_BUCKET` | **Yes** | — | Cloud Run env var | GCS bucket path (e.g., `gs://cure-hht-admin-schema`) |
| `SCHEMA_PREFIX` | No | `db-schema` | Cloud Run env var | GCS prefix inside bucket |
| `SCHEMA_FILE` | No | `init-consolidated.sql` | Cloud Run env var | Schema SQL filename in GCS |
| `SPONSOR_DATA_FILE` | No | `seed_data_dev.sql` | Cloud Run env var | Seed data SQL filename in GCS |
| `SPONSOR` | **Yes** | — | Cloud Run env var | Sponsor name (e.g., `callisto4`) |
| `ENVIRONMENT` | **Yes** | — | Cloud Run env var | Target environment (`dev`/`qa`/`uat`/`prod`) |
| `DEFAULT_USER_PWD` | No | — | Doppler or direct | Default password for seeded Identity Platform users |
| `RESET_IDS` | No | `false` | Cloud Run env var | Set to `true` to delete and re-seed Identity Platform users |
| `SKIP_IF_TABLES_EXIST` | No | `true` | Direct env var | Skip schema if tables already exist |
| `LOG_LEVEL` | No | `INFO` | Direct env var | Logging verbosity |

## Usage

```bash
# Preview via Cloud Run Job
gcloud run jobs execute deploy-db --region europe-west9

# Trigger via GitHub Actions workflow
# See .github/workflows/reset-db-gcp.yml
```
