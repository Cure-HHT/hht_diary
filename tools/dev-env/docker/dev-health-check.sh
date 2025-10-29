#!/bin/bash
set -e
# Base tools
git --version >/dev/null
gh --version >/dev/null
node --version >/dev/null
python3 --version >/dev/null
doppler --version >/dev/null
# Dev-specific tools
flutter --version >/dev/null
java -version >/dev/null 2>&1
sdkmanager --list >/dev/null 2>&1
echo "Dev health check passed"
