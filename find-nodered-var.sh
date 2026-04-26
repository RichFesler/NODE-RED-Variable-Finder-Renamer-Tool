#!/usr/bin/env bash
# Node-RED Variable Finder / Renamer Tool
# --------------------------------------
# Searches flows.json for exact variable matches (token-safe)
# Classifies READ / WRITE / MATCH
# Supports interactive rename with backup

#!/usr/bin/env bash

FLOW="${1:-$HOME/.node-red/flows.json}"

if [[ ! -f "$FLOW" ]]; then
  echo "ERROR: flow file not found: $FLOW"
  echo "Usage:"
  echo "  $0"
  echo "  $0 /path/to/flows.json"
  exit 1
fi

echo "Using flow file: $FLOW"
echo "A backup is created before changes."
echo

while true; do
  read -rp "Variable name: " NEEDLE
  [[ -z "$NEEDLE" ]] && continue

  python3 - "$FLOW" "$NEEDLE" <<'PY'
import json, sys, re

flow_file = sys.argv[1]
needle = sys.argv[2]

token_re = re.compile(rf'(?<![A-Za-z0-9_$]){re.escape(needle)}(?![A-Za-z0-9_$])')

with open(flow_file, "r", encoding="utf-8") as f:
    nodes = json.load(f)

tabs = {n.get("id"): n.get("label", n.get("id")) for n in nodes if n.get("type") == "tab"}
groups = {n.get("id"): n.get("name", n.get("id")) for n in nodes if n.get("type") == "group"}

rows = []

def tab(n): return tabs.get(n.get("z"), n.get("z", ""))
def group(n): return groups.get(n.get("g"), "")
def node_name(n): return n.get("name") or n.get("label") or "(unnamed)"

def store_for(scope, detail=""):
    d = str(detail)

    if "#:(filesystem)::" in d:
        return "file"
    if "#:(memory)::" in d:
        return "memory"

    if scope in ("global", "flow", "context"):
        return "default"
    if scope in ("msg", "object", "local"):
        return "memory"

    return "unknown"

def short_detail(s):
    s = str(s)
    s = s.replace("#:(filesystem)::", "global[file].")
    s = s.replace("#:(memory)::", "global[mem].")
    return s

def add(n, kind, scope, field, detail):
    rows.append({
        "kind": kind,
        "scope": scope,
        "store": store_for(scope, detail),
        "tab": tab(n),
        "group": group(n),
        "node": node_name(n),
        "type": n.get("type", ""),
        "field": field,
        "detail": detail,
    })

def classify_function_line(line):
    if re.search(rf'\bglobal\.set\(["\']{re.escape(needle)}["\']', line):
        return "WRITE", "global"
    if re.search(rf'\bglobal\.get\(["\']{re.escape(needle)}["\']', line):
        return "READ", "global"

    if re.search(rf'\bflow\.set\(["\']{re.escape(needle)}["\']', line):
        return "WRITE", "flow"
    if re.search(rf'\bflow\.get\(["\']{re.escape(needle)}["\']', line):
        return "READ", "flow"

    if re.search(rf'\bcontext\.set\(["\']{re.escape(needle)}["\']', line):
        return "WRITE", "context"
    if re.search(rf'\bcontext\.get\(["\']{re.escape(needle)}["\']', line):
        return "READ", "context"

    if re.search(rf'\bmsg(\.payload)?\.{re.escape(needle)}\s*=', line):
        return "WRITE", "msg"
    if re.search(rf'\bmsg(\.payload)?\.{re.escape(needle)}\b', line):
        return "READ", "msg"

    if re.search(rf'\b[A-Za-z_$][A-Za-z0-9_$]*\.{re.escape(needle)}\s*=', line):
        return "WRITE", "object"
    if re.search(rf'\b[A-Za-z_$][A-Za-z0-9_$]*\.{re.escape(needle)}\b', line):
        return "READ", "object"

    if re.search(rf'\b(let|const|var)\s+{re.escape(needle)}\b', line):
        return "WRITE", "local"

    if token_re.search(line):
        return "MATCH", "code"

    return "MATCH", "unknown"

def classify_change_rule(item):
    t = str(item.get("t", ""))
    p = str(item.get("p", ""))
    pt = str(item.get("pt", ""))
    to = str(item.get("to", ""))
    tot = str(item.get("tot", ""))

    if token_re.search(p):
        if t in ("set", "move"):
            return "WRITE", pt or "unknown"
        if t == "delete":
            return "DELETE", pt or "unknown"
        return t.upper() or "MATCH", pt or "unknown"

    if token_re.search(to):
        return "READ", tot or "unknown"

    return "MATCH", "config"

for n in nodes:
    for k, v in n.items():

        if isinstance(v, str):
            if not token_re.search(v):
                continue

            if "\n" in v:
                for i, line in enumerate(v.splitlines(), 1):
                    if token_re.search(line):
                        kind, scope = classify_function_line(line)
                        add(n, kind, scope, f"{k}:L{i}", line.strip())
            else:
                kind, scope = classify_function_line(v)

                if k in ("name", "label"):
                    kind, scope = "MATCH", "config"

                add(n, kind, scope, k, v)

        elif isinstance(v, list):
            for idx, item in enumerate(v):
                s = json.dumps(item, ensure_ascii=False)

                if not token_re.search(s):
                    continue

                if k == "rules" and isinstance(item, dict):
                    kind, scope = classify_change_rule(item)
                else:
                    kind, scope = "MATCH", "config"

                add(n, kind, scope, f"{k}[{idx}]", s)

        elif isinstance(v, dict):
            s = json.dumps(v, ensure_ascii=False)

            if token_re.search(s):
                add(n, "MATCH", "config", k, s)

order = {"WRITE": 0, "READ": 1, "DELETE": 2, "MATCH": 3}

rows.sort(key=lambda r: (
    order.get(r["kind"], 9),
    r["tab"],
    r["group"],
    r["node"],
    r["field"]
))

print()
print(f"VARIABLE: {needle}")
print("-" * 132)
print(f"{'#':<3} {'KIND':<5} {'VAR':<6} {'STORE':<7} {'TAB':<12} {'GROUP':<18} {'NODE':<24} {'FIELD':<10} DETAIL")
print("-" * 132)

if not rows:
    print("NO MATCHES")
else:
    for i, r in enumerate(rows, 1):
        detail = short_detail(r["detail"]).replace("\n", " ")

        if len(detail) > 64:
            detail = detail[:61] + "..."

        print(
            f"{i:<3} "
            f"{r['kind'][:5]:<5} "
            f"{r['scope'][:6]:<6} "
            f"{r['store'][:7]:<7} "
            f"{r['tab'][:12]:<12} "
            f"{r['group'][:18]:<18} "
            f"{r['node'][:24]:<24} "
            f"{r['field'][:10]:<10} "
            f"{detail}"
        )

print("-" * 132)
print(f"Total matches: {len(rows)}")
print()
PY

  while true; do
    read -rp "[F]ind again / [C]hange all / [Q]uit: " ACTION

    case "$ACTION" in
      f|F|"")
        break
        ;;

      q|Q)
        exit 0
        ;;

      c|C)
        read -rp "Change '$NEEDLE' to: " REPLACE
        [[ -z "$REPLACE" ]] && echo "Canceled: empty replacement." && continue

        echo
        echo "This replaces whole-token matches only."
        echo "FROM: $NEEDLE"
        echo "TO:   $REPLACE"
        echo "FILE: $FLOW"
        echo
        read -rp "Type YES to continue: " CONFIRM
        [[ "$CONFIRM" != "YES" ]] && echo "Canceled." && continue

        BACKUP="${FLOW}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$FLOW" "$BACKUP"

        python3 - "$FLOW" "$NEEDLE" "$REPLACE" <<'PY'
import sys, re

flow_file = sys.argv[1]
needle = sys.argv[2]
replace = sys.argv[3]

token_re = re.compile(rf'(?<![A-Za-z0-9_$]){re.escape(needle)}(?![A-Za-z0-9_$])')

with open(flow_file, "r", encoding="utf-8") as f:
    data = f.read()

data, count = token_re.subn(replace, data)

with open(flow_file, "w", encoding="utf-8") as f:
    f.write(data)

print(f"Changed {count} occurrence(s).")
PY

        echo "Backup saved: $BACKUP"
        echo
        echo "Restart Node-RED if needed:"
        echo "  node-red-restart"
        echo "  sudo systemctl restart nodered"
        echo
        break
        ;;

      *)
        echo "Use F, C, or Q."
        ;;
    esac
  done

done
