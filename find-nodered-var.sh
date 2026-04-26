#!/usr/bin/env bash
# Node-RED Variable Finder / Renamer Tool
# --------------------------------------
# Searches flows.json for exact variable matches (token-safe)
# Classifies READ / WRITE / MATCH
# Supports interactive rename with backup

FLOW="${1:-$HOME/.node-red/flows.json}"

if [[ ! -f "$FLOW" ]]; then
  echo "ERROR: flow file not found: $FLOW"
  exit 1
fi

echo "Using flow file: $FLOW"
echo "A backup is created before changes."
echo

while true; do
  read -rp "Variable name: " NEEDLE
  [[ -z "$NEEDLE" ]] && continue

  python3 - "$FLOW" "$NEEDLE" <<'PY'
# (trimmed for brevity in example package)
print("Script logic here - see GitHub for full version")
PY

  read -rp "[F]ind again / [C]hange all / [Q]uit: " ACTION
  case "$ACTION" in
    q|Q) exit 0 ;;
    *) ;;
  esac
done
