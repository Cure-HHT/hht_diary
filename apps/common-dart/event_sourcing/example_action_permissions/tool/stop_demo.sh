#!/usr/bin/env bash
# tool/stop_demo.sh
#
# Stops the demo server started by tool/run_demo.sh.

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.."

if [ -f tool/.demo-server.pid ]; then
  PID=$(cat tool/.demo-server.pid)
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    echo "demo server stopped (pid $PID)."
  else
    echo "demo server pid $PID is not running."
  fi
  rm -f tool/.demo-server.pid
else
  echo "no demo server pid file found."
fi
