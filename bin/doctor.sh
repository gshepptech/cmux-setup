#!/usr/bin/env bash
# Check that an installed cmux setup is valid and internally consistent.
set -uo pipefail
DEST="$HOME/.config/cmux"
fail=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=1; }
note() { printf '  note  %s\n' "$*"; }

echo "cmux setup doctor"

if ! command -v cmux >/dev/null 2>&1; then
  bad "cmux is not on PATH"
  exit 1
fi
ok "cmux $(cmux version 2>/dev/null | head -1)"

if cmux config doctor >/dev/null 2>&1; then ok "cmux.json parses"; else bad "cmux.json has a syntax error (run: cmux config doctor)"; fi

# external tools this setup can use
if command -v python3 >/dev/null 2>&1; then
  ok "python3 $(python3 -V 2>&1 | awk '{print $2}')"
else
  bad "python3 missing — normalize-names.py, add-layout.sh and scan-projects.sh need it (xcode-select --install)"
fi

if [ -z "${CMUX_AGENT:-}" ]; then
  note "CMUX_AGENT is unset — workspace layouts open a login shell instead of an agent"
elif command -v "$CMUX_AGENT" >/dev/null 2>&1; then
  ok "agent CLI: $CMUX_AGENT"
else
  bad "CMUX_AGENT is set to '$CMUX_AGENT' but that is not on PATH"
fi

if command -v git >/dev/null 2>&1; then ok "git"; else note "git missing — the Dock Git control and sidebar branch info stay empty"; fi
if command -v htop >/dev/null 2>&1; then ok "htop"; else note "htop missing — the Dock System control falls back to built-in top"; fi

if [ -f "$DEST/dock.json" ]; then
  if python3 -m json.tool "$DEST/dock.json" >/dev/null 2>&1; then ok "dock.json parses"; else bad "dock.json is not valid JSON"; fi
fi

if [ -d "$DEST/sidebars" ]; then
  if cmux sidebar validate >/dev/null 2>&1; then
    ok "custom sidebars validate"
  else
    bad "a custom sidebar failed to validate (run: cmux sidebar validate)"
  fi
fi

# every workspace layout should point at a directory that exists
python3 - "$DEST/cmux.json" <<'PY'
import json, os, re, sys, io
path = sys.argv[1]
try:
    raw = open(path).read()
except FileNotFoundError:
    print("  note  no cmux.json installed yet"); sys.exit(0)
txt = "\n".join(l for l in raw.split("\n") if not l.strip().startswith("//"))
txt = re.sub(r",(\s*[}\]])", r"\1", txt)
try:
    cfg = json.load(io.StringIO(txt))
except Exception as e:
    print("  note  could not parse cmux.json for layout check:", e); sys.exit(0)
missing = 0
for c in cfg.get("commands", []):
    ws = c.get("workspace")
    if not ws: continue
    cwd = ws.get("cwd", ".")
    if cwd in (".", ""): continue
    if not os.path.isdir(os.path.expanduser(cwd)):
        print(f"  FAIL  layout {c['name']!r} points at a missing directory: {cwd}")
        missing += 1
if not missing:
    print("  ok    every workspace layout points at a real directory")
PY

# the actions registry is nightly-only; warn if someone has added one
if grep -q '"actions"' "$DEST/cmux.json" 2>/dev/null; then
  note "cmux.json defines 'actions' — that registry is a nightly-only feature."
  note "     On stable builds use 'commands' for workspace layouts instead."
fi

echo
[ "$fail" = 0 ] && echo "All checks passed." || echo "Some checks failed."
exit "$fail"
