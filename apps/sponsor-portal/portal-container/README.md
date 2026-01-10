# Sponsor Portal Container

Combined container running the Sponsor Portal web UI and API server for Cloud Run.

## Overview

This container packages both the Flutter web frontend and Dart API backend into a single deployment unit. nginx serves the static Flutter files and proxies API requests to the Dart server.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Cloud Run                          │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │           nginx (port 8080)                  │    │
│  │                                              │    │
│  │   /           → Flutter web static files     │    │
│  │   /api/*      → Dart server (port 8081)      │    │
│  │   /health     → Dart server (port 8081)      │    │
│  └─────────────────────────────────────────────┘    │
│                       │                              │
│                       ▼                              │
│  ┌─────────────────────────────────────────────┐    │
│  │        Dart Server (port 8081)               │    │
│  │                                              │    │
│  │   portal_server + portal_functions           │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## What's Included

- **Flutter Web UI**: Pre-built static files served by nginx
- **Dart API Server**: Compiled AOT executable
- **nginx**: Reverse proxy and static file server
- **Health endpoint**: `/health` for Cloud Run probes

## Endpoints

| Path                       | Handler      | Description                |
|----------------------------|--------------|----------------------------|
| `/`                        | nginx        | Flutter web UI             |
| `/api/v1/sponsor/config`   | Dart server  | Sponsor configuration      |
| `/api/v1/portal/me`        | Dart server  | Current user info          |
| `/api/v1/portal/users`     | Dart server  | User management (Admin)    |
| `/api/v1/portal/sites`     | Dart server  | Clinical sites             |
| `/health`                  | Dart server  | Health check               |

## Building

### Prerequisites

Requires these base images in Artifact Registry:
- `flutter-base:${FLUTTER_VERSION}`
- `dart-base:${DART_VERSION}`

### With Cloud Build

```bash
gcloud builds submit \
  --config=apps/sponsor-portal/portal-container/cloudbuild.yaml \
  --substitutions=_FLUTTER_VERSION=3.24.0,_DART_VERSION=3.5.0
```

### Locally (for testing)

```bash
source .github/versions.env

docker build \
  --build-arg DART_VERSION=$DART_VERSION \
  --build-arg FLUTTER_VERSION=$FLUTTER_VERSION \
  --build-arg GCP_PROJECT_ID=your-project-id \
  -f apps/sponsor-portal/portal-container/Dockerfile \
  -t sponsor-portal:local \
  .
```

## Running Locally

```bash
docker run -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=sponsor_portal \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e DB_SSL=false \
  -e FIREBASE_AUTH_EMULATOR_HOST=host.docker.internal:9099 \
  sponsor-portal:local
```

Then open http://localhost:8080 in your browser.

## Environment Variables

| Variable                      | Description                  | Default               |
|-------------------------------|------------------------------|-----------------------|
| `DB_HOST`                     | PostgreSQL host              | `localhost`           |
| `DB_PORT`                     | PostgreSQL port              | `5432`                |
| `DB_NAME`                     | Database name                | `sponsor_portal`      |
| `DB_USER`                     | Database user                | `postgres`            |
| `DB_PASSWORD`                 | Database password            | (required)            |
| `DB_SSL`                      | Enable SSL                   | `true`                |
| `GCP_PROJECT_ID`              | GCP project ID               | `demo-sponsor-portal` |
| `FIREBASE_AUTH_EMULATOR_HOST` | Firebase emulator host       | (unset = production)  |

## Container Details

- **Base image**: debian:bookworm-slim
- **Exposed port**: 8080
- **User**: non-root (appuser)
- **Processes**: nginx (foreground) + Dart server (background)

## Artifact Registry

- **Region**: europe-west1 (GDPR compliance)
- **Repository**: hht-diary
- **Image**: `europe-west1-docker.pkg.dev/PROJECT_ID/hht-diary/sponsor-portal:VERSION`

## Files

| File              | Purpose                                |
|-------------------|----------------------------------------|
| `Dockerfile`      | Multi-stage build (Flutter + Dart)     |
| `nginx.conf`      | nginx routing configuration            |
| `start.sh`        | Container entrypoint script            |
| `cloudbuild.yaml` | Cloud Build configuration              |

## Related

- [Portal Server](../portal_server/README.md) - Dart API server
- [Portal Functions](../portal_functions/README.md) - Business logic
- [Portal UI](../portal-ui/README.md) - Flutter web frontend
