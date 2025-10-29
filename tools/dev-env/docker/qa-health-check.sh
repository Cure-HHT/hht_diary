#!/bin/bash
set -e
# Base tools
git --version >/dev/null
gh --version >/dev/null
node --version >/dev/null
python3 --version >/dev/null
doppler --version >/dev/null
# QA-specific tools
flutter --version >/dev/null
npx playwright --version >/dev/null 2>&1
pandoc --version >/dev/null
echo "QA health check passed"
