#!/bin/bash
# Coverage wrapper - delegates to test.sh --coverage
# All coverage options (--no-threshold, etc.) are passed through.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/test.sh" --coverage "$@"
