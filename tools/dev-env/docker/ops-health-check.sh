#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#
# Health check for ops (DevOps) environment
# Validates infrastructure and deployment tools

set -e

# Base tools (inherited from base image)
git --version >/dev/null
gh --version >/dev/null
node --version >/dev/null
python3 --version >/dev/null
doppler --version >/dev/null

# Ops-specific tools
terraform --version >/dev/null
supabase --version >/dev/null
aws --version >/dev/null
kubectl version --client >/dev/null 2>&1
cosign version >/dev/null
syft version >/dev/null
grype version >/dev/null

echo "Ops health check passed"
