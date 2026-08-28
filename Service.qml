import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null

  // Apply the user's launchpad.json rules when the shell (and Hyprland) start.
  // The generator writes ~/.config/hypr/launchpad.lua and reloads Hyprland;
  // o.launch_on_start entries then fire on hyprland.start.
  Process {
    id: applyOnBoot
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/generate.py"]
    running: true
  }

  // Exposed over IPC as `omarchy-shell shell call yuuki.launchpad reload`,
  // so the bar widget's "Reload config" and external scripts can re-apply.
  function reload() {
    applyOnBoot.running = false
    applyOnBoot.running = true
    return "ok"
  }
}
