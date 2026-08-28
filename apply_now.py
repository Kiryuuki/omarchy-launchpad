#!/usr/bin/env python3
"""Apply the user's launchpad.json workspace rules to currently running windows.

For each entry that has a `workspace`, find running Hyprland windows whose
class or title matches `match` (as a regex, falling back to substring) and
move them to the assigned workspace via `hyprctl eval`.

Returns a JSON object on stdout:
  {"moved": 3, "skipped": 1}

"skipped" counts windows already on the right workspace.
"""
import json
import os
import re
import subprocess
import sys


def _hyprctl_json(cmd: str):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    if p.returncode != 0:
        return []
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return []


def _match_window(window, pattern: str) -> bool:
    cls = (window.get("class") or "").lower()
    title = (window.get("title") or "").lower()
    try:
        return bool(re.search(pattern, cls, re.IGNORECASE)) or bool(
            re.search(pattern, title, re.IGNORECASE)
        )
    except re.error:
        return pattern.lower() in cls or pattern.lower() in title


def _move_window(address: str, workspace: int):
    cmd = f"hyprctl eval 'return hl.dsp.window.move({{workspace={workspace}}}, \"{address}\")'"
    subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)


def main() -> int:
    home = os.environ.get("HOME", os.path.expanduser("~"))
    config_path = os.path.join(home, ".config", "omarchy", "launchpad.json")

    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        entries = data.get("entries", []) if isinstance(data, dict) else []
    except (OSError, json.JSONDecodeError):
        entries = []

    windows = _hyprctl_json("hyprctl clients -j")
    moved = 0
    skipped = 0

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        ws = entry.get("workspace")
        match = str(entry.get("match", "")).strip()
        if not ws or not match:
            continue
        try:
            ws_int = int(ws)
        except (TypeError, ValueError):
            continue
        for w in windows:
            if not _match_window(w, match):
                continue
            current_ws = w.get("workspace", {}).get("id")
            if current_ws == ws_int:
                skipped += 1
            else:
                _move_window(w.get("address", ""), ws_int)
                moved += 1

    print(json.dumps({"moved": moved, "skipped": skipped}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
