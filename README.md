# Launchpad — Omarchy app → workspace manager

A small Omarchy shell plugin that lets you **declaratively pin apps to
workspaces** and optionally **auto-launch them at boot**, driven entirely by a
single config file you own. Nothing is hardcoded in the plugin.

- **Workspace pinning** — every time an app opens, it lands on the workspace you
  assigned (via a generated Hyprland window rule).
- **Boot launch** — apps flagged `launchAtBoot` start automatically at login.
- **Bar widget** — a button that lists your apps (with their workspace + boot
  flag), launches/focuses each on click, and has a **Reload config** action.
- **Plugin code and user data are separate** — the plugin lives in
  `~/.config/omarchy/plugins/yuuki.launchpad/`; your app list lives in
  `~/.config/omarchy/launchpad.json`.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-launchpad.git --enable --yes
```

Or, for local development, copy the folder in and enable it:

```bash
cp -r . ~/.config/omarchy/plugins/yuuki.launchpad
omarchy plugin enable yuuki.launchpad
```

Validate before publishing:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/yuuki.launchpad
```

## Configure

Copy the example into your user config and edit it:

```bash
cp ~/.config/omarchy/plugins/yuuki.launchpad/launchpad.example.json \
   ~/.config/omarchy/launchpad.json
```

Each entry in `entries`:

| Field           | Type    | Meaning                                                              |
|-----------------|---------|----------------------------------------------------------------------|
| `id`            | string  | A name for the app (shown in the menu). Optional; falls back to match. |
| `match`         | string  | Hyprland window-rule matcher (usually the window class, e.g. `zen`). **Required** if `workspace` is set. |
| `workspace`     | int     | Workspace number to pin the app to. Omit to skip pinning.            |
| `silent`        | bool    | If true, pinning does not steal focus to that workspace. Default false. |
| `launchAtBoot`  | bool    | If true, launch the app at login. **Requires `command`.**            |
| `command`       | string  | The launch command (e.g. `zen-browser`). Used by boot launch + the menu's launch action. |

After editing, either reopen the Launchpad menu and click **Reload config**, or
run:

```bash
python3 ~/.config/omarchy/plugins/yuuki.launchpad/scripts/generate.py
```

This regenerates `~/.config/hypr/launchpad.lua` (read by your `hyprland.lua`)
and reloads Hyprland. The generated file is never edited by hand — your
`launchpad.json` is the source of truth.

## How it works

- `scripts/generate.py` reads `launchpad.json` and writes
  `~/.config/hypr/launchpad.lua`, which uses Omarchy's `o.window(match,
  { workspace = "N" })` helper for pinning and `o.launch_on_start(command)`
  for boot launches. It idempotently adds `require("hypr.launchpad")` to your
  `~/.config/hypr/hyprland.lua`.
- `Service.qml` runs the generator when the shell starts, so the rules apply at
  boot even before the bar widget mounts.
- A `post-boot.d` hook also runs the generator after the desktop comes up, as a
  fallback.
- The `BarWidget.qml` reads `launchpad.json` to render its menu and calls the
  generator's "Reload" path on demand.

All writes stay in `~/.config/`. The plugin never touches `/usr/share/omarchy`.

## Uninstall

```bash
omarchy plugin remove yuuki.launchpad --yes
# Optional cleanup of generated Hyprland glue:
omarchy refresh hyprland        # restores default hyprland.lua (backs up first)
rm -f ~/.config/hypr/launchpad.lua
rm -f ~/.config/omarchy/launchpad.json
```

## License

MIT
