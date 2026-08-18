#!/usr/bin/env bash
# Install this cmux setup into ~/.config/cmux.
#
#   ./install.sh              install (backs up anything it replaces)
#   ./install.sh --dry-run    show what would happen, change nothing
#   ./install.sh --uninstall  remove installed files, restore newest backups
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/cmux"
STAMP="$(date +%Y%m%d%H%M%S)"
DRY=0
UNINSTALL=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a" >&2; exit 1 ;;
  esac
done

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then say "  would: $*"; else "$@"; fi; }

FILES=(
  "cmux.json:config/cmux.json"
  "dock.json:config/dock.json"
  "sidebars/hq.swift:sidebars/hq.swift"
  "sidebars/status-board.swift:sidebars/status-board.swift"
  "normalize-names.py:bin/normalize-names.py"
)

if [ "$UNINSTALL" = 1 ]; then
  say "Uninstalling from $DEST"
  for pair in "${FILES[@]}"; do
    target="$DEST/${pair%%:*}"
    [ -e "$target" ] || continue
    newest="$(ls -1t "$target".*.bak 2>/dev/null | head -1 || true)"
    if [ -n "$newest" ]; then
      say "restore $target  <-  $(basename "$newest")"
      run mv "$newest" "$target"
    else
      say "remove  $target"
      run rm -f "$target"
    fi
  done
  [ "$DRY" = 1 ] || cmux reload-config >/dev/null 2>&1 || true
  say "Done."
  exit 0
fi

say "Installing into $DEST"
[ "$DRY" = 1 ] && say "(dry run — nothing will be written)"

run mkdir -p "$DEST/sidebars"

for pair in "${FILES[@]}"; do
  rel="${pair%%:*}"
  from="$SRC/${pair##*:}"
  target="$DEST/$rel"
  if [ -e "$target" ]; then
    say "backup  $target  ->  $(basename "$target").$STAMP.bak"
    run cp "$target" "$target.$STAMP.bak"
  fi
  say "install $rel"
  run cp "$from" "$target"
done

run chmod +x "$DEST/normalize-names.py"

if [ "$DRY" = 0 ]; then
  say ""
  "$SRC/bin/doctor.sh" || true
  say ""
  say "Installed. Next:"
  say "  1. Right-click the sidebar toggle button and choose 'hq'"
  say "  2. Optional: ./bin/scan-projects.sh ~/your/code/dir   (per-project icons + colours)"
  say "  3. Optional: ./bin/add-layout.sh ~/your/repo          (a workspace layout for one repo)"
fi
