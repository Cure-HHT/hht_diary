#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00030: CI/CD Environment Parity
#
# Test Docker registry caching workflow locally
# Simulates CI build-push-build pattern with local registry

set -e

echo "=========================================="
echo "Local Registry Testing Script"
echo "=========================================="
echo ""

# Check if local registry is running
if ! docker ps | grep -q "registry:2"; then
    echo "Starting local Docker registry on port 5000..."
    docker run -d -p 5000:5000 --restart=always --name local-registry registry:2
    echo "✓ Local registry started"
else
    echo "✓ Local registry already running"
fi

echo ""
echo "Building and pushing images in dependency order..."
echo ""

# Build and push base
echo "1/3: Building base image..."
docker compose --profile build-only -f docker-compose.yml -f docker-compose.local.yml build base
echo "    Pushing to local registry..."
docker push localhost:5000/clinical-diary-base:latest
echo "✓ Base image ready in registry"
echo ""

# Build and push dev
echo "2/3: Building dev image (depends on base from registry)..."
docker compose --profile build-only -f docker-compose.yml -f docker-compose.local.yml build dev
echo "    Pushing to local registry..."
docker push localhost:5000/clinical-diary-dev:latest
echo "✓ Dev image ready in registry"
echo ""

# Build and push qa
echo "3/3: Building qa image (depends on dev from registry)..."
docker compose --profile build-only -f docker-compose.yml -f docker-compose.local.yml build qa
echo "    Pushing to local registry..."
docker push localhost:5000/clinical-diary-qa:latest
echo "✓ QA image ready in registry"
echo ""

echo "=========================================="
echo "✓ All images built and pushed successfully!"
echo "=========================================="
echo ""
echo "Registry contents:"
echo ""
# List images in registry
curl -s http://localhost:5000/v2/_catalog | jq .

echo ""
echo "To stop the local registry:"
echo "  docker stop local-registry && docker rm local-registry"
echo ""
echo "To test registry caching, run this script again."
echo "Subsequent builds will use cached layers from the registry."
