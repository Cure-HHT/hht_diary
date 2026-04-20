#!/bin/bash
# Launch a local Grafana LGTM stack and demo server to visualize OTel traces.
#
# Prerequisites:
#   - Docker (with Compose v2)
#   - Dart SDK
#
# What this does:
#   1. Starts Grafana LGTM (OTel Collector + Tempo + Loki + Prometheus + Grafana)
#   2. Waits for the collector to be ready
#   3. Starts the demo Shelf server that exercises all otel_common APIs
#   4. Fires sample requests to generate traces
#   5. Opens Grafana in your browser
#
# Usage:
#   ./tool/local_otel_demo.sh          # Start everything
#   ./tool/local_otel_demo.sh --down   # Tear down the stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PACKAGE_DIR/../../../../tools/dev-env/docker-compose.otel.yml"

# Tear down if requested.
if [[ "${1:-}" == "--down" ]]; then
    echo "Stopping LGTM stack..."
    docker compose -f "$COMPOSE_FILE" down
    echo "Done."
    exit 0
fi

echo "=== otel_common Local Demo ==="
echo ""

# 1. Start the LGTM stack.
echo "[1/4] Starting Grafana LGTM stack..."
docker compose -f "$COMPOSE_FILE" up -d

# 2. Wait for OTel Collector to accept connections.
echo "[2/4] Waiting for OTel Collector (port 4318)..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:4318/v1/traces -X POST -d '{}' -o /dev/null 2>/dev/null; then
        echo "  Collector ready."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "  ERROR: Collector not ready after 30s. Check: docker compose -f $COMPOSE_FILE logs"
        exit 1
    fi
    sleep 1
done

# 3. Resolve deps and start demo server in background.
echo "[3/4] Starting demo server..."
(cd "$PACKAGE_DIR" && dart pub get --no-precompile 2>/dev/null)
(cd "$PACKAGE_DIR" && dart run example/demo_server.dart) &
DEMO_PID=$!

# Wait for server to be ready.
for i in $(seq 1 15); do
    if curl -sf http://localhost:8080/health -o /dev/null 2>/dev/null; then
        break
    fi
    sleep 1
done

# 4. Generate sample traffic.
echo "[4/4] Generating sample traces..."
echo ""
for i in $(seq 1 5); do
    curl -s http://localhost:8080/api/patients > /dev/null
    curl -s http://localhost:8080/api/slow > /dev/null
    curl -s http://localhost:8080/api/error > /dev/null
    curl -s http://localhost:8080/health > /dev/null
done
echo "  Sent 20 requests (5x each endpoint)."
echo ""

# Open Grafana.
GRAFANA_URL="http://localhost:3000/explore"
echo "=== Ready ==="
echo ""
echo "  Grafana:      $GRAFANA_URL"
echo "  Demo server:  http://localhost:8080"
echo ""
echo "In Grafana Explore:"
echo "  1. Select 'Tempo' datasource (top-left dropdown)"
echo "  2. Click 'Search' tab"
echo "  3. Set Service Name = 'otel-demo-server'"
echo "  4. Click 'Run query'"
echo ""
echo "Keep generating traffic:"
echo "  curl http://localhost:8080/api/patients"
echo "  curl http://localhost:8080/api/slow"
echo "  curl http://localhost:8080/api/error"
echo ""
echo "Press Ctrl+C to stop the demo server."
echo "Run './tool/local_otel_demo.sh --down' to tear down the LGTM stack."

# Try to open browser.
if command -v xdg-open &> /dev/null; then
    xdg-open "$GRAFANA_URL" 2>/dev/null || true
elif command -v open &> /dev/null; then
    open "$GRAFANA_URL" 2>/dev/null || true
fi

# Wait for demo server.
wait $DEMO_PID 2>/dev/null || true
