#!/usr/bin/env bash
set -euo pipefail

SIGNAL_DIR="$HOME/Library/Application Support/Patchlet"
mkdir -p "$SIGNAL_DIR"
touch "$SIGNAL_DIR/task-complete.signal"
echo "Patchlet task-complete signal sent."
