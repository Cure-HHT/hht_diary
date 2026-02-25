#!/usr/bin/env bash
# Local diary server startup.
# Run with: doppler run -- ./tool/run_local.sh
# Doppler provides LOCAL_DB_PASSWORD for app_user.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Extract component versions for local dev
DIARY_SERVER_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
DIARY_FUNCTIONS_VERSION=$(grep '^version:' ../diary_functions/pubspec.yaml | sed 's/version: //')
TRIAL_DATA_TYPES_VERSION=$(grep '^version:' ../../common-dart/trial_data_types/pubspec.yaml | sed 's/version: //')

DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=sponsor_portal \
DB_USER=app_user \
DB_PASSWORD="${LOCAL_DB_PASSWORD:?Set LOCAL_DB_PASSWORD in Doppler}" \
DB_SSL=false \
JWT_SECRET=test-secret-for-local-dev \
PORT=8080 \
dart run \
  -DDIARY_SERVER_VERSION="$DIARY_SERVER_VERSION" \
  -DDIARY_FUNCTIONS_VERSION="$DIARY_FUNCTIONS_VERSION" \
  -DTRIAL_DATA_TYPES_VERSION="$TRIAL_DATA_TYPES_VERSION" \
  bin/server.dart
