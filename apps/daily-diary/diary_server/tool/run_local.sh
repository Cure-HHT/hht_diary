#!/usr/bin/env bash
# Local diary server startup.
# Run with: doppler run -- ./tool/run_local.sh
# Doppler provides LOCAL_DB_PASSWORD for app_user.
DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=sponsor_portal \
DB_USER=app_user \
DB_PASSWORD="${LOCAL_DB_PASSWORD:?Set LOCAL_DB_PASSWORD in Doppler}" \
DB_SSL=false \
JWT_SECRET=test-secret-for-local-dev \
PORT=8080 \
dart run bin/server.dart
