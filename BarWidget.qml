import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "yuuki.launchpad"

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

  property bool menuOpen: false

  // Live copy of the user's launchpad.json, so the menu reflects current config.
  property var entries: []

  function refreshConfig() {
    configProc.running = true
  }

  function launchEntry(cmd) {
    if (!cmd) return
    launchProc.command = ["bash", "-c", "omarchy launch or focus .* \"" + cmd + "\""]
    launchProc.running = true
  }

  function reloadRules() {
    applyProc.running = true
  }

  Component.onCompleted: refreshConfig()

  // Read ~/.config/omarchy/launchpad.json (user data, separate from plugin code).
  Process {
    id: configProc
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/read_config.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.entries = JSON.parse(text || "[]")
        } catch (e) {
          root.entries = []
        }
      }
    }
  }

  // Launch-or-focus a configured app.
  Process { id: launchProc; command: ["true"] }

  // Regenerate Hyprland rules + boot launches from launchpad.json.
  Process {
    id: applyProc
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/generate.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refreshConfig()
    }
  }

  BarIconButton {
    id: btn
    bar: root.bar
    text: ""
    onPressed: function(button) {
      if (button === Qt.RightButton) return
      root.menuOpen = !root.menuOpen
    }
  }

  PopupCard {
    id: menu
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(260))
    contentHeight: menu.fittedContentHeight(menuCol.implicitHeight)

    Column {
      id: menuCol
      anchors.fill: parent
      spacing: Style.space(6)
      leftPadding: Style.space(10)
      rightPadding: Style.space(10)
      topPadding: Style.space(8)
      bottomPadding: Style.space(8)

      Text {
        text: "Launchpad"
        color: root.fg
        font.family: root.fontFam
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        visible: root.entries.length === 0
        text: "No apps configured.\nEdit ~/.config/omarchy/launchpad.json"
        color: Qt.darker(root.fg, 1.5)
        font.family: root.fontFam
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Repeater {
        model: root.entries
        delegate: Item {
          required property var modelData
          required property int index
          width: menuCol.width
          implicitHeight: 30
          readonly property string label: (modelData.id || modelData.match || ("#" + index))
          readonly property string ws: (modelData.workspace !== undefined && modelData.workspace !== null) ? ("WS " + modelData.workspace) : "—"
          readonly property string boot: modelData.launchAtBoot ? "⏏" : ""

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            text: label
            color: root.fg
            font.family: root.fontFam
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            text: ws + "  " + boot
            color: Qt.darker(root.fg, 1.4)
            font.family: root.fontFam
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.launchEntry(modelData.command)
              root.menuOpen = false
            }
          }
        }
      }

      Button {
        text: "Reload config"
        foreground: root.fg
        fontFamily: root.fontFam
        horizontalPadding: 8
        verticalPadding: 4
        fontSize: Style.font.bodySmall
        onClicked: {
          root.reloadRules()
          root.menuOpen = false
        }
      }
    }
  }
}
