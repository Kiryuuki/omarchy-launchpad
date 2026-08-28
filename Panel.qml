import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: panelRoot
  moduleName: "yuuki.launchpad"
  ipcTarget: "yuuki.launchpad"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: (bar && bar.foreground !== undefined) ? bar.foreground : Color.foreground
  readonly property color bg: Color.popups.background
  readonly property string fontFam: bar ? bar.fontFamily : Style.font.family

  // ---- data ----
  property var allApps: []          // [{id,name,command}]
  property var currentEntries: []   // [{match,command,workspace,launchAtBoot}]
  property bool isRefreshing: false
  property string statusText: ""

  function loadApps() {
    panelRoot.isRefreshing = true
    panelRoot.statusText = ""
    listProc.running = true
  }

  function loadEntries() {
    configProc.running = true
  }

  function save() {
    var payload = JSON.stringify({ entries: panelRoot.currentEntries })
    saveProc.running = false
    saveProc.running = true
  }

  function applyNow() {
    panelRoot.isRefreshing = true
    panelRoot.statusText = "Applying…"
    applyProc.running = true
  }

  function reloadRules() {
    panelRoot.isRefreshing = true
    panelRoot.statusText = "Reloading…"
    reloadProc.running = true
  }

  function done(msg) {
    panelRoot.isRefreshing = false
    panelRoot.statusText = msg
    Qt.callLater(function() {
      if (panelRoot.statusText) panelRoot.statusText = ""
    }, 2500)
  }

  function entryForCommand(cmd) {
    for (var i = 0; i < panelRoot.currentEntries.length; i++) {
      if (panelRoot.currentEntries[i].command === cmd) return panelRoot.currentEntries[i]
    }
    return null
  }

  function workspaceOptions() {
    var opts = []
    opts.push({ value: 0, label: "—" })
    var wl = bar && typeof bar.workspaces === "function" ? bar.workspaces() : []
    if (wl && wl.length > 0) {
      for (var i = 0; i < wl.length; i++) {
        var id = wl[i].id !== undefined ? wl[i].id : (i + 1)
        var name = wl[i].name || String(id)
        opts.push({ value: id, label: "WS " + name })
      }
    } else {
      for (var j = 1; j <= 10; j++) opts.push({ value: j, label: "WS " + String(j) })
    }
    return opts
  }

  // ---- IPC ----
  Process {
    id: listProc
    command: ["/usr/bin/python3",
      (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/list_apps.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { panelRoot.allApps = JSON.parse(text || "[]") }
        catch (e) { panelRoot.allApps = [] }
        panelRoot.isRefreshing = false
      }
    }
  }

  Process {
    id: configProc
    command: ["/usr/bin/python3",
      (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/read_config.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { panelRoot.currentEntries = JSON.parse(text || "[]") }
        catch (e) { panelRoot.currentEntries = [] }
        panelRoot.isRefreshing = false
      }
    }
  }

  Process {
    id: applyProc
    command: ["/usr/bin/python3",
      (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/apply_now.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var obj = JSON.parse(text || "{}")
          panelRoot.done("Moved " + obj.moved + " window(s)")
        } catch (e) {
          panelRoot.done("Apply finished")
        }
      }
    }
  }

  Process {
    id: reloadProc
    command: ["/usr/bin/python3",
      (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/generate.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: panelRoot.done("Rules reloaded")
    }
  }

  Process {
    id: saveProc
    // Write payload to a temp file in the same directory so save_config.py
    // can atomically replace launchpad.json without shell-quoting JSON.
    command: [
      "/usr/bin/python3",
      "-c",
      'import json, os, tempfile; '
      + 'entries = ' + JSON.stringify(currentEntries) + '; '
      + 'd = os.path.expanduser("~/.config/omarchy"); '
      + 'fd, p = tempfile.mkstemp(dir=d, suffix=".tmp"); '
      + 'os.write(fd, (json.dumps({"entries": entries}, indent=2) + "\\n").encode()); '
      + 'os.close(fd); os.replace(p, os.path.join(d, "launchpad.json")); '
      + 'print("wrote " + str(len(entries)) + " entries")'
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        panelRoot.done("Saved. Click Apply now to move open windows.")
        Qt.callLater(function() { panelRoot.loadEntries() }, 200)
      }
    }
  }

  // ---- UI ----
  function open() { panelController.show() }
  function close() { panelController.hide() }
  function toggle() { panelRoot.opened ? panelRoot.close() : panelRoot.open() }

  Component.onCompleted: {
    loadApps()
    loadEntries()
  }

  Rectangle {
    id: content
    anchors.fill: parent
    color: panelRoot.bg
    radius: Style.space(2)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      Text {
        text: "Launchpad"
        color: panelRoot.fg
        font.family: panelRoot.fontFam
        font.pixelSize: Style.font.body
        font.bold: true
      }

      TextField {
        id: searchField
        width: parent.width
        placeholderText: "Search installed apps…"
        color: panelRoot.fg
        font.family: panelRoot.fontFam
        background: Rectangle { color: Qt.darker(panelRoot.bg, 1.2); radius: 4; border.color: Qt.darker(panelRoot.fg, 2); border.width: 1 }
        onTextChanged: filterApps()
        function filterApps() {
          var q = (searchField.text || "").toLowerCase().trim()
          // handled by delegate visibility
        }
      }

      ScrollView {
        width: parent.width
        height: Math.min(Style.space(400), Style.space(50) + Math.max(0, panelRoot.allApps.length) * Style.space(52))
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
          spacing: Style.space(4)
          width: parent.width

          Repeater {
            model: panelRoot.allApps
            delegate: Item {
              required property var modelData
              property bool configured: !!panelRoot.entryForCommand(modelData.command)
              property bool matchesFilter: {
                var q = (searchField.text || "").toLowerCase().trim()
                if (!q) return true
                return (modelData.name + " " + modelData.command).toLowerCase().indexOf(q) >= 0
              }
              visible: matchesFilter
              width: parent.width
              height: configured ? Style.space(52) : 0
              opacity: configured ? 1 : (matchesFilter ? 0.5 : 0)

              RowLayout {
                anchors.fill: parent
                anchors.margins: Style.space(4)
                spacing: Style.space(8)

                Text {
                  Layout.fillWidth: true
                  text: modelData.name
                  color: panelRoot.fg
                  font.family: panelRoot.fontFam
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                ComboBox {
                  Layout.preferredWidth: Style.space(120)
                  model: panelRoot.workspaceOptions()
                  textRole: "label"
                  valueRole: "value"
                  font.family: panelRoot.fontFam
                  font.pixelSize: Style.font.caption
                  enabled: configured
                  currentIndex: {
                    var entry = panelRoot.entryForCommand(modelData.command)
                    if (!entry) return 0
                    var ws = entry.workspace || 0
                    var opts = panelRoot.workspaceOptions()
                    for (var i = 0; i < opts.length; i++) { if (opts[i].value === ws) return i }
                    return 0
                  }
                  onActivated: function(idx) {
                    var opts = panelRoot.workspaceOptions()
                    var entry = panelRoot.entryForCommand(modelData.command)
                    if (!entry) {
                      entry = { match: modelData.name, command: modelData.command, workspace: 0, launchAtBoot: false }
                      panelRoot.currentEntries.push(entry)
                    }
                    entry.workspace = opts[idx].value
                  }
                }

                CheckBox {
                  text: "Boot"
                  font.family: panelRoot.fontFam
                  font.pixelSize: Style.font.caption
                  enabled: configured
                  checked: {
                    var entry = panelRoot.entryForCommand(modelData.command)
                    return entry ? !!entry.launchAtBoot : false
                  }
                  onClicked: function() {
                    var entry = panelRoot.entryForCommand(modelData.command)
                    if (entry) entry.launchAtBoot = checked
                  }
                }

                Button {
                  text: configured ? "Remove" : "Add"
                  font.family: panelRoot.fontFam
                  font.pixelSize: Style.font.caption
                  Layout.preferredWidth: Style.space(64)
                  onClicked: {
                    var entry = panelRoot.entryForCommand(modelData.command)
                    if (entry) {
                      var idx = panelRoot.currentEntries.indexOf(entry)
                      if (idx >= 0) panelRoot.currentEntries.splice(idx, 1)
                    } else {
                      panelRoot.currentEntries.push({
                        match: modelData.name,
                        command: modelData.command,
                        workspace: 0,
                        launchAtBoot: false,
                      })
                    }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        id: statusLabel
        text: panelRoot.statusText
        color: Qt.darker(panelRoot.fg, 1.3)
        font.family: panelRoot.fontFam
        font.pixelSize: Style.font.caption
        visible: !!text
      }

      RowLayout {
        spacing: Style.space(8)

        Button {
          text: "Save"
          font.family: panelRoot.fontFam
          font.pixelSize: Style.font.bodySmall
          onClicked: panelRoot.save()
        }
        Button {
          text: "Apply now"
          font.family: panelRoot.fontFam
          font.pixelSize: Style.font.bodySmall
          onClicked: panelRoot.applyNow()
        }
        Button {
          text: "Reload config"
          font.family: panelRoot.fontFam
          font.pixelSize: Style.font.bodySmall
          onClicked: panelRoot.reloadRules()
        }
      }
    }
  }
}
