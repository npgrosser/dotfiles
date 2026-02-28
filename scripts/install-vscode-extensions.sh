#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_FILE="$SCRIPT_DIR/../config/vscode-extensions.txt"

if ! command -v code >/dev/null 2>&1; then
  echo "Error: 'code' command not found. Is VS Code installed and in PATH?"
  exit 1
fi

if [ ! -f "$EXTENSIONS_FILE" ]; then
  echo "Error: extensions file not found: $EXTENSIONS_FILE"
  exit 1
fi

echo "==> Installing VS Code extensions..."
while IFS= read -r ext || [ -n "$ext" ]; do
  ext="$(echo "$ext" | xargs)"
  [ -z "$ext" ] && continue
  [[ "$ext" == \#* ]] && continue
  echo "  - $ext"
  code --install-extension "$ext" --force 2>/dev/null || echo "    (failed)"
done < "$EXTENSIONS_FILE"

echo "==> Done."
