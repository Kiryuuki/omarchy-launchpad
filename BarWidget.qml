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
  property var entries: []

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  function openPanel() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  Component.onCompleted: refreshConfig()

  Process {
    id: configProc
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/read_config.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.entries = JSON.parse(text || "[]") }
        catch (e) { root.entries = [] }
      }
    }
  }

  Process { id: launchProc; command: ["true"] }

  Process {
    id: applyProc
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/yuuki.launchpad/scripts/generate.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refreshConfig()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf135"
    tooltipText: "Launchpad: app workspace manager"
    onPressed: function(b) {
      if (b === Qt.RightButton) return
      root.togglePanel()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: Qt.callLater(function() {
      if (panelLoader.item && typeof panelLoader.item.injectPanel === "function") panelLoader.item.injectPanel()
    })
  }

  PopupCard {
    id: menu
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen && !panelLoader.item || !panelLoader.item.opened
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
        text: "No apps configured.\nUse the settings panel to add apps."
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
        text: "Open settings"
        foreground: root.fg
        fontFamily: root.fontFam
        horizontalPadding: 8
        verticalPadding: 4
        fontSize: Style.font.bodySmall
        onClicked: {
          root.menuOpen = false
          Qt.callLater(root.openPanel)
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
