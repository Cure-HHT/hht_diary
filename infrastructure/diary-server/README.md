# Diary Server Container

Shelf HTTP server hosting diary functions for Cloud Run.

## Overview

This container runs the Dart functions for the dairy app as a shelf HTTP server. 
It uses the `dart-base` image as its build stage parent.

## What's Included

- Compiled Dart executable (AOT)
- diary_functions library (business logic)
- diary_server (shelf HTTP handler)
- Health check endpoint at `/health`

## Dependencies

- **dart-base**: Parent image for build stage
- **trial_data_types**: Shared Dart types
- **diary_functions**: Business logic package

## Endpoints

| Path                     | Method | Description                     |
|--------------------------|--------|---------------------------------|
| `/health`                | GET    | Health check for Cloud Run      |
| `/api/v1/auth/register`  | POST   | User registration (planned)     |
| `/api/v1/auth/login`     | POST   | User login (planned)            |
| `/api/v1/sponsor/config` | GET    | Sponsor configuration (planned) |

## Building

### With Cloud Build

```bash
gcloud builds submit --config=infrastructure/diary-server/cloudbuild.yaml
```

### Locally (for testing)

```bash
source .github/versions.env
docker build \
  --build-arg DART_VERSION=$DART_VERSION \
  --build-arg GCP_PROJECT_ID=your-project-id \
  -f infrastructure/diary-server/Dockerfile \
  -t diary-server:local \
  .
```

## Running Locally

```bash
docker run -p 8080:8080 diary-server:local
curl http://localhost:8080/health
```

## Environment Variables

| Variable | Description                  | Default |
|----------|------------------------------|---------|
| `PORT`   | HTTP port (set by Cloud Run) | 8080    |

## Artifact Registry

- **Region**: europe-west1 (GDPR compliance)
- **Repository**: hht-diary
- **Image**: `europe-west1-docker.pkg.dev/PROJECT_ID/hht-diary/diary-server:VERSION`

## Related Files

- `apps/diaryserver/diary_functions/` - Business logic package
- `apps/diaryserver/diary_server/` - Shelf server package
- `infrastructure/dart-base/` - Base Dart image
