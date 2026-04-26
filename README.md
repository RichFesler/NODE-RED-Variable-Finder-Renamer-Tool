# Node-RED Variable Finder & Refactor Tool

## Overview (Short)
Command-line tool to locate, classify, and safely rename variables inside Node-RED `flows.json`.

## Overview (Long)
This tool solves a core Node-RED problem:

> There is no native way to track variable usage across flows.

When renaming variables (especially `global`, `flow`, or `msg.payload`), manual search is error-prone and incomplete.

This tool:
- Scans entire flow JSON
- Finds exact variable matches (no partial collisions)
- Classifies usage:
  - READ
  - WRITE
  - MATCH (config/UI)
- Displays:
  - Tab
  - Group
  - Node
  - Type
- Supports safe bulk rename with:
  - Token-aware replacement
  - Automatic timestamped backup

---

## Features

- Exact variable matching (no substring false positives)
- Supports:
  - Function nodes
  - Change nodes
  - Switch nodes
  - Debug nodes
  - UI/template nodes
- Distinguishes:
  - msg
  - global
  - flow
  - context
  - object/local
- Identifies storage type:
  - memory
  - default context
  - filesystem (if used)

---

## Installation

```bash
chmod +x find-nodered-var.sh
```

---

## Usage

```bash
./find-nodered-var.sh
```

Optional custom flow file:

```bash
./find-nodered-var.sh /path/to/flows.json
```

---

## Workflow

1. Enter variable name
2. Review matches
3. Choose:
   - F → next search
   - C → rename everywhere (safe)
   - Q → exit

---

## Safety

Before any rename:

- Backup created:
  ```
  flows.json.bak.YYYYMMDD-HHMMSS
  ```

---

## Notes

- Variable matching is token-based:
  - `localTime` ≠ `GEO_localTime`
- Persistence depends on:
  ```
  ~/.node-red/settings.js
  ```

---

## License

MIT
