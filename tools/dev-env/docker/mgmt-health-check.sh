#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#
# Health check for mgmt (Management) environment
# Validates read-only audit and reporting tools

set -e

# Base tools only (no development tools needed)
git --version >/dev/null
gh --version >/dev/null
jq --version >/dev/null
doppler --version >/dev/null

echo "Mgmt health check passed"
