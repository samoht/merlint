#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRACE_DIR="$(cd "${1:-$SCRIPT_DIR/../traces}" && pwd)"
echo "x" > "$TRACE_DIR/out.csv"
