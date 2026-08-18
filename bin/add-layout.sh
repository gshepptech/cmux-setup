#!/usr/bin/env bash
# Generate a cmux workspace layout for one repository and add it to cmux.json.
#
#   ./bin/add-layout.sh ~/path/to/repo
#   ./bin/add-layout.sh --dry-run ~/path/to/repo
#
# Reads the repo's package.json / go.mod / Cargo.toml to pick the right dev and
# test commands, then writes a "commands" entry that opens an agent beside them.
# The agent pane runs $CMUX_AGENT, or a login shell when that is unset.
set -euo pipefail

DRY=0
REPO=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) REPO="$a" ;;
  esac
done
[ -n "$REPO" ] || { sed -n '2,8p' "$0"; exit 1; }
REPO="$(cd "$REPO" && pwd)"

CFG="$HOME/.config/cmux/cmux.json"
AGENT="${CMUX_AGENT:-}"

ENTRY=$(REPO="$REPO" AGENT="$AGENT" python3 <<'PY'
import json, os

repo = os.environ["REPO"]
agent = os.environ["AGENT"]
name = os.path.basename(repo)
title = " ".join(w[:1].upper() + w[1:] for w in name.replace("_", "-").split("-"))

dev = test = None
sub = ""

pkg_dirs = [""] + [d for d in ("web", "app", "frontend", "client", "site")
                   if os.path.exists(os.path.join(repo, d, "package.json"))]
for d in pkg_dirs:
    pkg = os.path.join(repo, d, "package.json")
    if not os.path.exists(pkg):
        continue
    try:
        scripts = json.load(open(pkg)).get("scripts", {})
    except Exception:
        continue
    pm = "npm run"
    if os.path.exists(os.path.join(repo, d, "pnpm-lock.yaml")): pm = "pnpm"
    elif os.path.exists(os.path.join(repo, d, "bun.lockb")): pm = "bun run"
    elif os.path.exists(os.path.join(repo, d, "yarn.lock")): pm = "yarn"
    if "dev" in scripts: dev = f"{pm} dev"
    for t in ("test:watch", "test"):
        if t in scripts:
            test = f"{pm} {t}"
            break
    sub = d
    break

if dev is None:
    if os.path.exists(os.path.join(repo, "go.mod")):
        dev, test = "go run ./...", "go test ./..."
    elif os.path.exists(os.path.join(repo, "Cargo.toml")):
        dev, test = "cargo run", "cargo test"

home = os.path.expanduser("~")
cwd = repo.replace(home, "~", 1) if repo.startswith(home) else repo

def surface(nm, cmd, focus=False, scwd=None):
    s = {"type": "terminal", "name": nm}
    if cmd: s["command"] = cmd
    if scwd: s["cwd"] = scwd
    if focus: s["focus"] = True
    return s

guarded = (f'command -v {agent} >/dev/null 2>&1 && exec {agent} || exec ${{SHELL:-/bin/zsh}} -l'
           if agent else
           '[ -n "$CMUX_AGENT" ] && command -v "$CMUX_AGENT" >/dev/null 2>&1 && exec "$CMUX_AGENT" || exec ${SHELL:-/bin/zsh} -l')
agent_pane = {"pane": {"surfaces": [surface("Agent", guarded, focus=True)]}}
scwd = f"./{sub}" if sub else None

if dev and test:
    right = {"direction": "vertical", "split": 0.5, "children": [
        {"pane": {"surfaces": [surface("Dev Server", dev, scwd=scwd)]}},
        {"pane": {"surfaces": [surface("Tests", test, scwd=scwd)]}},
    ]}
elif dev:
    right = {"pane": {"surfaces": [surface("Dev Server", dev, scwd=scwd)]}}
else:
    right = {"pane": {"surfaces": [surface("Shell", None)]}}

entry = {
    "name": f"{title} Dev",
    "description": f"Agent beside the dev commands for {name}",
    "keywords": [name, "dev"],
    "workspace": {
        "name": title,
        "cwd": cwd,
        "layout": {"direction": "horizontal", "split": 0.55,
                   "children": [agent_pane, right]},
    },
}
print(json.dumps(entry, indent=2))
PY
)

echo "$ENTRY"

if [ "$DRY" = 1 ]; then exit 0; fi
[ -f "$CFG" ] || { echo "No cmux.json at $CFG — run ./install.sh first." >&2; exit 1; }

cp "$CFG" "$CFG.$(date +%Y%m%d%H%M%S).bak"
ENTRY="$ENTRY" python3 - "$CFG" <<'PY'
import os, sys
p = sys.argv[1]
s = open(p).read()
entry = os.environ["ENTRY"]

key = s.index('"commands"')
start = s.index("[", key)
depth, i = 0, start
while i < len(s):
    if s[i] == "[":
        depth += 1
    elif s[i] == "]":
        depth -= 1
        if depth == 0:
            break
    i += 1
end = i

lines = s[start + 1:end].split("\n")
meaningful = [n for n, l in enumerate(lines) if l.strip() and not l.strip().startswith("//")]
indented = ["    " + l if l.strip() else l for l in entry.split("\n")]

if meaningful:
    last = meaningful[-1]
    if not lines[last].rstrip().endswith(","):
        lines[last] = lines[last].rstrip() + ","
    lines = lines[:last + 1] + indented + lines[last + 1:]
else:
    lines = indented + lines

open(p, "w").write(s[:start + 1] + "\n".join(lines) + s[end:])
PY
cmux config doctor >/dev/null 2>&1 && echo "Added to $CFG" || { echo "cmux.json failed validation — restoring backup" >&2; mv "$(ls -1t "$CFG".*.bak | head -1)" "$CFG"; exit 1; }
cmux reload-config >/dev/null 2>&1 || true
