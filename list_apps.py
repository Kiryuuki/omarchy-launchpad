#!/usr/bin/env python3
"""Emit installed .desktop app names as a JSON array on stdout.

Used by the Launchpad settings panel to build the searchable app list.
Combines /usr/share/applications and ~/.local/share/applications, dedupes
by desktop file basename, sorts by Name, and skips NoDisplay=true entries.
"""
import configparser
import json
import os
import sys


def _parse_desktop(path: str):
    cp = configparser.ConfigParser(interpolation=None)
    try:
        cp.read(path, encoding="utf-8", errors="replace")
    except Exception:
        return None
    sec = cp["Desktop Entry"] if "Desktop Entry" in cp else (
        cp[cp.sections()[0]] if cp.sections() else None
    )
    if sec is None:
        return None
    name = sec.get("Name", "")
    no_display = sec.get("NoDisplay", "false").strip().lower()
    if not name or no_display == "true":
        return None
    exec_val = sec.get("Exec", "")
    # Strip field codes (%u, %f, etc.) to get a usable command stem.
    if "%" in exec_val:
        exec_val = exec_val.split("%")[0].strip()
    return {"id": os.path.basename(path), "name": name.strip(), "command": exec_val.strip()}


def main() -> None:
    home = os.environ.get("HOME", os.path.expanduser("~"))
    dirs = [
        "/usr/share/applications",
        os.path.join(home, ".local", "share", "applications"),
    ]
    seen = {}
    for directory in dirs:
        if not os.path.isdir(directory):
            continue
        for entry in os.listdir(directory):
            if not entry.endswith(".desktop"):
                continue
            path = os.path.join(directory, entry)
            info = _parse_desktop(path)
            if info is None:
                continue
            key = info["name"].lower()
            if key not in seen:
                seen[key] = info
    apps = sorted(seen.values(), key=lambda x: x["name"].lower())
    print(json.dumps(apps))


if __name__ == "__main__":
    main()
