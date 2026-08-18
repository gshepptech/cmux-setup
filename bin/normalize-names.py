#!/usr/bin/env python3
"""Normalize cmux workspace and tab names to one house style.

  - strips agent status glyphs from the front of a title
  - Title Case, small words lowered mid-title, brand casing preserved

  normalize-names.py            dry run, prints what would change
  normalize-names.py --apply    performs the renames
  normalize-names.py --reset    clears every pinned tab name (titles go back to
                                tracking whatever the agent is doing live)
"""
import json, subprocess, sys

APPLY = "--apply" in sys.argv
RESET = "--reset" in sys.argv

SMALL = {"a", "an", "the", "and", "or", "of", "to", "in", "for",
         "on", "at", "by", "with", "vs", "from"}
BRAND = {"cmux": "cmux", "macos": "macOS", "ios": "iOS", "pr": "PR", "prs": "PRs",
         "cli": "CLI", "ui": "UI", "ux": "UX", "api": "API", "ssh": "SSH",
         "tui": "TUI", "mcp": "MCP", "ai": "AI", "id": "ID", "url": "URL",
         "json": "JSON", "sdk": "SDK", "qa": "QA", "e2e": "E2E", "npm": "npm"}
GLYPHS = "✳◐◑◒◓●○◉⏺✦✧✻✽*·•▪◆◇⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ "


def norm(title):
    t = title.lstrip(GLYPHS).strip()
    if not t:
        return ""
    words = t.split()
    out = []
    for i, w in enumerate(words):
        low = w.lower()
        key = low.strip(".,:;!?")
        if key in BRAND:
            out.append(BRAND[key] + w[len(key):])
        elif low in SMALL and 0 < i < len(words) - 1:
            out.append(low)
        elif "/" in w:
            out.append("/".join(p[:1].upper() + p[1:] for p in w.split("/")))
        elif w.isupper() and len(w) > 1:
            out.append(w)
        else:
            out.append(w[:1].upper() + w[1:])
    return " ".join(out)


def rename(cmd):
    if APPLY:
        subprocess.run(cmd, check=True, capture_output=True)


tree = json.loads(subprocess.run(["cmux", "tree", "--all", "--json"],
                                 check=True, capture_output=True, text=True).stdout)

if RESET:
    cleared = 0
    for win in tree.get("windows", []):
        for ws in win.get("workspaces", []):
            for pane in ws.get("panes", []):
                for sf in pane.get("surfaces", []):
                    subprocess.run(["cmux", "tab-action", "--action", "clear-name",
                                    "--workspace", ws["ref"], "--tab", sf["ref"]],
                                   capture_output=True)
                    cleared += 1
    print("{} tab name(s) cleared - titles now track the agent again.".format(cleared))
    sys.exit(0)

changes = 0
for win in tree.get("windows", []):
    for ws in win.get("workspaces", []):
        old = ws.get("title") or ""
        new = norm(old)
        if new and new != old:
            changes += 1
            print("  workspace {:<14} {!r} -> {!r}".format(ws["ref"], old, new))
            rename(["cmux", "workspace-action", "--action", "rename",
                    "--workspace", ws["ref"], "--title", new])
        for pane in ws.get("panes", []):
            for sf in pane.get("surfaces", []):
                oldt = sf.get("title") or ""
                newt = norm(oldt)
                if newt and newt != oldt:
                    changes += 1
                    print("  tab       {:<14} {!r} -> {!r}".format(sf["ref"], oldt, newt))
                    rename(["cmux", "tab-action", "--action", "rename",
                            "--workspace", ws["ref"], "--tab", sf["ref"],
                            "--title", newt])

print("\n{} name(s) {}.".format(changes, "renamed" if APPLY else "would change"))
if not APPLY and changes:
    print("Run with --apply to perform the renames.")
