#!/usr/bin/env bash
# tool/run_demo.sh
#
# Spawns the demo server in the background, then runs the Flutter client
# on Linux desktop. Logs go to tool/.demo-server.log; pid in
# tool/.demo-server.pid.

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.."

mkdir -p tool

# Kill any prior server (best effort).
if [ -f tool/.demo-server.pid ]; then
  PRIOR_PID=$(cat tool/.demo-server.pid)
  if kill -0 "$PRIOR_PID" 2>/dev/null; then
    echo "killing prior demo server (pid $PRIOR_PID)..."
    kill "$PRIOR_PID" 2>/dev/null || true
    sleep 1
  fi
  rm -f tool/.demo-server.pid
fi

# Start the server.
nohup dart run bin/server.dart \
  --ephemeral \
  --permissions-yaml=tool/permissions.yaml \
  --users-yaml=tool/users.yaml \
  > tool/.demo-server.log 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > tool/.demo-server.pid
echo "demo server started (pid $SERVER_PID); logs at tool/.demo-server.log"

# Wait briefly for the server to come up.
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
    echo "demo server is healthy."
    break
  fi
  sleep 1
done

# Run the Flutter client in the foreground.
flutter run -d linux
