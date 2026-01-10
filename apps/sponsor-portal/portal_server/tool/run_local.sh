#!/usr/bin/env bash
DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=hht_portal \
DB_USER=app_user \
DB_PASSWORD=devpassword \
DB_SSL=false \
JWT_SECRET=test-secret-for-local-dev \
PORT=8080 \
dart run bin/server.dart
