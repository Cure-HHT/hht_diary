#!/bin/bash
# Basic health check: verify essential tools
set -e
git --version >/dev/null
gh --version >/dev/null
node --version >/dev/null
python3 --version >/dev/null
doppler --version >/dev/null
echo "Health check passed"
