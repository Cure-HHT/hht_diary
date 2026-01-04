# Base Dart Container

Base Docker image for all Dart server containers in the HHT Diary platform.

## Purpose

Provides a minimal, secure Dart runtime that child containers inherit from. This speeds up builds by caching the Dart SDK layer.

## What's Included

- Dart SDK (version pinned in `.github/versions.env`)
- curl (for health checks)
- ca-certificates (for HTTPS)
- Non-root user (`appuser`) for security

## What's NOT Included

- PostgreSQL client libraries (not needed - Dart's `postgres` package is pure Dart)
- Flutter SDK (use separate Flutter images for web builds)
- Application code (added by child containers)

## Usage

### In Child Dockerfiles

```dockerfile
ARG DART_VERSION=3.6.0
FROM us-central1-docker.pkg.dev/PROJECT_ID/hht-diary/dart-base:${DART_VERSION}

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy source and compile
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

CMD ["./bin/server"]
```

### Building Locally

```bash
docker build -t dart-base:local .
```

### Building with Cloud Build

```bash
cd infrastructure/dart-base
gcloud builds submit --config=cloudbuild.yaml
```

## Version Management

Dart version is pinned in `.github/versions.env`:
```
DART_VERSION=3.6.0
```

Update the version there, then rebuild and push the base image.

## Security

- Runs as non-root user (`appuser`)
- Minimal attack surface (only essential packages)
- No secrets or credentials baked in
