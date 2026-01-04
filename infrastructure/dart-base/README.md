# Base Dart Container

Base Docker image for all Dart server containers in the HHT Diary platform.

## Purpose

Provides a minimal, secure Dart runtime that child containers inherit from. This speeds up builds by caching the Dart SDK layer.

## What's Included

- Dart SDK (version from `.github/versions.env`)
- curl (for health checks)
- ca-certificates (for HTTPS)
- Non-root user (`appuser`) for security

## What's NOT Included

- PostgreSQL client libraries (not needed - Dart's `postgres` package is pure Dart)
- Flutter SDK (use separate Flutter images for web builds)
- Application code (added by child containers)

## Version Management

**Single source of truth**: `.github/versions.env`

```bash
DART_VERSION=3.10.1
```

The cloudbuild.yaml reads from versions.env automatically.

## Usage

### In Child Dockerfiles

```dockerfile
ARG DART_VERSION
FROM europe-west1-docker.pkg.dev/PROJECT_ID/hht-diary/dart-base:${DART_VERSION}

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy source and compile
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

CMD ["./bin/server"]
```

### Building with Cloud Build

```bash
cd infrastructure/dart-base
gcloud builds submit --config=cloudbuild.yaml
```

Version is read from `.github/versions.env` automatically.

### Building Locally (for testing)

```bash
source .github/versions.env
docker build --build-arg DART_VERSION=$DART_VERSION -t dart-base:local .
```

## Artifact Registry

- **Region**: europe-west1 (GDPR compliance)
- **Repository**: hht-diary
- **Image**: `europe-west1-docker.pkg.dev/PROJECT_ID/hht-diary/dart-base:VERSION`

## Security

- Runs as non-root user (`appuser`)
- Minimal attack surface (only essential packages)
- No secrets or credentials baked in
