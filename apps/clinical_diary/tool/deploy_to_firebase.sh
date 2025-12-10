#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Deploying the Clinical Diary to Firebase
# Optionally deploy --only hosting or --only functions
# Usage: ./tool/build_web_dev.sh [hosting|functions]

set -e

echo "Deploying the Clinical Diary to Firebase ..."

firebase deploy

echo ""
echo "Deploy complete!"
