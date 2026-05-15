#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv-build}"
APP_NAME="${APP_NAME:-Patchlet}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python3 was not found. Install Python 3.10+ before building."
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller

rm -rf build dist
pyinstaller \
  --noconfirm \
  --windowed \
  --name "$APP_NAME" \
  --add-data "assets:assets" \
  main.py

echo "Built dist/$APP_NAME.app"
